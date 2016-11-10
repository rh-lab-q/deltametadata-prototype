import os
import re
from subprocess import PIPE, DEVNULL, CalledProcessError, Popen, check_output, check_call
import dnf
import logging

logger = logging.getLogger("dnf")


class PluginImpl(object):

    def __init__(self, mtdt_url, print_log = False):
        self.mtdt_url = mtdt_url
        self._cache_dir = None
        self.print_log = print_log
        self.wget_download = ['comps.*\.xz', 'updateinfo\.xml\.xz',
                              'prestodelta\.xml\.xz']
        self.zsync_download = ['primary\.xml\.gz', 'filelists\.xml\.gz']

    def download_repomd(self):
        " May throw if repomd.xml does not exists at server "
        with open(os.devnull, 'w') as FNULL:
            return check_output([
                'wget', self.mtdt_url + 'repomd.xml', '-O-'
            ], stderr=FNULL).decode('utf-8')

    def load_local_repomd(self):
        " return None if cache_dir/repomd.xml was not found "
        try:
            with open(self._cache_dir + '/repodata/repomd.xml', 'r') as repomd:
                return repomd.read()
        except:
            pass

    def repodata_base_name(self, s):
        " strips hash like this: [0-9a-f]+-(.+) -> \1 "
        return s.split('-')[1]

    def get_input_name(self, repomd, file_name):
        if repomd:
            return re.search(
                r'<location href=\"repodata/(.*' +
                file_name + r')\"',
                repomd
            ).group(1)
        else:
            return file_name

    def download_wget_file(self, file):
        try:
            check_call(['wget', self.mtdt_url + file, '-O', self._cache_dir +
                        '/repodata/' + file], stdout=DEVNULL, stderr=DEVNULL)
        except CalledProcessError as ex:
            logger.debug(str(ex))

    def save_repomd(self, repomd):
        with open(self._cache_dir + '/repodata/repomd.xml', 'w') as repomd_f:
            repomd_f.write(repomd)

    def remove_file_ext(self, file_name):
        return file_name[:file_name.rfind('.')]

    def sync_metadata(self, cache_dir):
        self._cache_dir = cache_dir
        repomd = self.download_repomd()

        if not os.path.exists(cache_dir):
                os.makedirs(cache_dir)
                os.makedirs(cache_dir + '/repodata')
                for file in self.wget_download:
                    self.download_wget_file(self.get_input_name(repomd, file))
                for file in self.zsync_download:
                    self.download_wget_file(self.get_input_name(repomd, file))
                self.save_repomd(repomd)
                return
        local_repomd = self.load_local_repomd()
        cwd = os.getcwd()
        os.chdir(cache_dir + '/repodata')

        for file in self.wget_download:
            new_file = self.get_input_name(repomd, file)
            old_file = self.get_input_name(local_repomd, file)
            if new_file.find(old_file) != 0:
                if (os.path.isfile(cache_dir + '/repodata/' + old_file)):
                    os.remove(cache_dir + '/repodata/' + old_file)
                self.download_wget_file(new_file)

        for file in self.zsync_download:
            new_file = self.get_input_name(repomd, file)
            old_file = self.get_input_name(local_repomd, file)
            if new_file.find(old_file) != 0:
                self._sync(
                    self.mtdt_url + self.remove_file_ext(new_file) + '.zsync',
                    cache_dir + '/repodata/' + old_file,
                    cache_dir + '/repodata/' + new_file
                )

        self.save_repomd(repomd)
        os.chdir(cwd)

    def _sync(self, url, input_file, target):
        " this is exception safe (unless something unexpected will happen) "
        # if file that will be synced does not exists, this should be aborted
        if not os.path.isfile(input_file):
            check_output(['touch', input_file])
        try:
            zsync = Popen(['zsync', url, '-i', input_file, '-o',
                           target], stdout=PIPE, stderr=PIPE)
            outputs = zsync.communicate()
            if zsync.returncode or self.print_log:
                logger.debug(outputs[1].decode('utf-8'))
                logger.debug(outputs[0].decode('utf-8'))
        except CalledProcessError as ex:
            logger.debug(str(ex))
            # reverse rewriting existing if there was any
            try:
                check_output(['mv', target + '.zs-old', target])
            except:
                pass
        else:
            # cleanup
            check_output(['rm', '-rf', target + '.zs-old',
                          input_file if input_file != target else ''])
        return zsync.returncode


class Plugin(dnf.Plugin):

    name = 'zsync'

    def __init__(self, base, cli):
        super(Plugin, self).__init__(base, cli)
        self.cli = cli
        self.base = base
        self.impl = PluginImpl('http://dmd-deltametadata.rhcloud.com/local/')

    def config(self):
        if self.cli:
            self.cli.demands.cacheonly = True
            self.base.repos['updates'].md_only_cached = True
            self.impl.sync_metadata(self.base.repos['updates'].cachedir)
