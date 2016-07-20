import os.path
import os
import re
from subprocess import PIPE, CalledProcessError, Popen, check_output

import dnf


class PluginImpl(object):

    def __init__(self, mtdt_url, print_log=False):
        self.mtdt_url = mtdt_url
        self._print_log = print_log

    def download_repomd(self):
        " May throw if repomd.xml does not exists at server "
        with open(os.devnull, 'w') as FNULL:
            return check_output([
                'wget', self.mtdt_url + 'repomd.xml', '-O-'
            ], stderr=FNULL).decode('utf-8')

    def load_local_repomd(self, cache_dir):
        " return None if cache_dir/repomd.xml was not found "
        try:
            with open(cache_dir + '/repomd.xml', 'r') as repomd:
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
                self.repodata_base_name(file_name) +
                r')\"',
                repomd
            ).group(1)
        else:
            return file_name

    def sync_metadata(self, cache_dir):
        def iter_repodata(repomd):
            return re.finditer(
                r'<location href=\"repodata/(.*)(\.(?:gz))\"',
                repomd
            )

        repomd = self.download_repomd()
        local_repomd = self.load_local_repomd(cache_dir)
        for loc in iter_repodata(repomd):
            file_name = loc.group(1)
            input_name = self.get_input_name(
                local_repomd, file_name + loc.group(2))
            self._sync(
                self.mtdt_url + file_name + '.zsync',
                cache_dir + '/repodata/' + input_name,
                cache_dir + '/repodata/' + file_name + loc.group(2)
            )
        with open(cache_dir + '/repomd.xml', 'w') as repomd_f:
            repomd_f.write(repomd)

    def _sync(self, url, input_file, target):
        " this is exception safe (unless something unexpected will happen) "
        # if file that will be synced does not exists, this should be aborted
        if not os.path.isfile(input_file):
            check_output(['touch', input_file])
        try:
            zsync = Popen(['zsync', url, '-i', input_file, '-o',
                           target], stdout=PIPE, stderr=PIPE)
            outputs = zsync.communicate()
            if self._print_log:
                print(outputs[1].decode('utf-8'))
                print(outputs[0].decode('utf-8'))
        except CalledProcessError as ex:
            # print(str(ex), file=sys.stderr)
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
