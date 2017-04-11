import os
import re
from subprocess import STDOUT, PIPE, DEVNULL, CalledProcessError, Popen,\
                       check_output, check_call
import dnf
import logging
from tempfile import mkdtemp
from shutil import copyfile, rmtree, move
from fcntl import fcntl, F_GETFL, F_SETFL

logger = logging.getLogger("dnf")


class PluginImpl(object):

    def __init__(self, mtdt_url, print_log=False):
        self.mtdt_url = mtdt_url
        self._cache_dir = None
        self._backup_dir = None
        self.print_log = print_log
        self.download = [('comps.*\.(gz|xz)', False), ('updateinfo\.xml\.(gz|xz)', False),
                         ('prestodelta\.xml\.(gz|xz)', False), ('primary\.xml\.gz',
                         True), ('filelists\.xml\.gz', True)]

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

    def backup_files(self):
        if self._backup_dir is None:
            self._backup_dir = mkdtemp()
            src_path = self._cache_dir + "/repodata"
            for file in os.listdir(src_path):
                srcfile = os.path.join(src_path, file)
                dstfile = os.path.join(self._backup_dir, file)
                copyfile(srcfile, dstfile)

    def restore_files(self):
        rmtree(self._cache_dir + '/repodata/')
        move(self._backup_dir, self._cache_dir + '/repodata/')

    def clean_backup_files(self):
        if self._backup_dir is not None:
            rmtree(self._backup_dir)

    def get_input_name(self, repomd, file_name):
        if repomd:
            regex = re.search(r'<location href=\"repodata/(.*' + file_name +
                              r')\"', repomd)
            return regex.group(1) if regex is not None else file_name
        else:
            return file_name

    def download_wget(self, file):
        try:
            check_call(['wget', self.mtdt_url + file, '-O', self._cache_dir +
                        '/repodata/' + file], stdout=DEVNULL, stderr=DEVNULL)
        except CalledProcessError as ex:
            logger.debug(str(ex))
            raise ex

    def save_repomd(self, repomd):
        with open(self._cache_dir + '/repodata/repomd.xml', 'w') as repomd_f:
            repomd_f.write(repomd)

    def remove_file_ext(self, file_name):
        return file_name[:file_name.rfind('.')]

    def async_read(self, process):
        output = []
        characters = []
        pattern = '###################- 100.0% 0.0 kBps'
        pattern_repeat = 0

        # set non-blocking flag while preserving old flags
        fl = fcntl(process.stdout, F_GETFL)
        fcntl(process.stdout, F_SETFL, fl | os.O_NONBLOCK)
        # read char until EOF hit
        while True:
            try:
                ch = os.read(process.stdout.fileno(), 1)
                # EOF
                if not ch:
                    break
                ch = ch.decode('UTF-8')
                characters.append(ch)
                # New line - check the pattern and add to output string
                if ch == '\n':
                    string = "".join(characters)
                    if (string.find(pattern) != -1):
                        pattern_repeat += 1
                        if (pattern_repeat == 2):
                            # zsync is in loop (bug)
                            Popen.kill(process)
                            break
                    output.append(string)
                    characters = []
            except OSError:
                # waiting for data be available on process.stdout
                pass
        return "".join(output)

    def sync_metadata(self, cache_dir):
        self._cache_dir = cache_dir
        repomd = self.download_repomd()

        if not os.path.exists(cache_dir):
            os.makedirs(cache_dir)
            os.makedirs(cache_dir + '/repodata')
            for file in self.download:
                if self.get_input_name(repomd, file[0]) != file[0]:
                    self.download_wget(self.get_input_name(repomd, file[0]))
            self.save_repomd(repomd)
            return

        local_repomd = self.load_local_repomd()
        cwd = os.getcwd()
        os.chdir(cache_dir + '/repodata')

        for file in self.download:
            new_file = self.get_input_name(repomd, file[0])
            old_file = self.get_input_name(local_repomd, file[0])
            if new_file.find(old_file) != 0:
                # second item of touple represent to synchronize or download
                self.backup_files()
                if file[1]:
                    if self._sync(
                        self.mtdt_url + self.remove_file_ext(new_file) +
                        '.zsync', cache_dir + '/repodata/' + old_file,
                            cache_dir + '/repodata/' + new_file) == 0:
                        # if zsync success, it can download next file
                        continue
                else:
                    if os.path.isfile(cache_dir + '/repodata/' + old_file):
                        os.remove(cache_dir + '/repodata/' + old_file)
                try:
                    self.download_wget(new_file)
                except CalledProcessError:
                    # if wget fails, restore old metadata
                    self.restore_files()
                    return

        self.save_repomd(repomd)
        self.clean_backup_files()
        os.chdir(cwd)

    def _sync(self, url, input_file, target):
        " this is exception safe (unless something unexpected will happen) "
        # if file that will be synced does not exists, this should be aborted
        rc = 0
        if not os.path.isfile(input_file):
            check_output(['touch', input_file])
        try:
            zsync = Popen(['zsync', url, '-i', input_file, '-o',
                           target], stdout=PIPE, stderr=STDOUT)
            outputs = self.async_read(zsync)
            if zsync.returncode:
                logger.debug(outputs)
                os.remove(input_file + '.part')
                rc = 1
            if self.print_log:
                logger.debug(outputs)
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
        return rc


class Plugin(dnf.Plugin):

    name = 'zsync'

    def __init__(self, base, cli):
        super(Plugin, self).__init__(base, cli)
        self.cli = cli
        self.base = base
        self.impl = PluginImpl('http://209.132.178.35/' + base.conf.releasever +
                               '/')

    def config(self):
        if self.cli:
            self.cli.demands.cacheonly = True
            self.base.repos['updates'].md_only_cached = True
            self.impl.sync_metadata(self.base.repos['updates'].cachedir)
