#!/usr/bin/python2
import sys
from xml.dom import minidom


def read_timestamp(root):
    result = {}
    for node in root.getElementsByTagName("data"):
        if node.getAttribute("type") == "filelists":
            tmp = node.getElementsByTagName("timestamp")[0]
            result['filelists'] = tmp.firstChild.data
            tmp = node.getElementsByTagName("checksum")[0]
            result['download_f'] = tmp.firstChild.data + "-filelists.xml.gz"
        elif node.getAttribute("type") == "primary":
            tmp = node.getElementsByTagName("timestamp")[0]
            result['primary'] = tmp.firstChild.data
            tmp = node.getElementsByTagName("checksum")[0]
            result['download_p'] = tmp.firstChild.data + "-primary.xml.gz"
        elif node.getAttribute("type") == "group_gz":
            tmp = node.getElementsByTagName("checksum")[0]
            result['download_g'] = tmp.firstChild.data + "-comps-f23.xml.xz"
        elif node.getAttribute("type") == "updateinfo":
            tmp = node.getElementsByTagName("checksum")[0]
            result['download_u'] = tmp.firstChild.data + "-updateinfo.xml.xz"
        elif node.getAttribute("type") == "prestodelta":
            tmp = node.getElementsByTagName("checksum")[0]
            result['download_d'] = tmp.firstChild.data + "-prestodelta.xml.xz"
    return result


def save_xml(xml):
    f = open(sys.argv[1], "w")
    out_str = xml.toxml(encoding="UTF-8")
    f.write(out_str.encode("utf-8"))
    f.write("\n".encode("utf-8"))
    f.close()


def print_files(files):
    print files['download_f']
    print files['download_p']
    print files['download_g']
    print files['download_u']
    print files['download_d']


def change_checksum(root):
    for node in root.getElementsByTagName("data"):
        if node.getAttribute("type") == "filelists":
            tmp = node.getElementsByTagName("checksum")[0]
            new_child = root.createTextNode(unicode(sys.argv[2]))
            tmp.replaceChild(new_child, tmp.firstChild)
            tmp = node.getElementsByTagName("location")[0]
            tmp.setAttribute("href", "repodata/" + sys.argv[2] +
                             "-filelists.xml.gz")
        elif node.getAttribute("type") == "primary":
            tmp = node.getElementsByTagName("checksum")[0]
            new_child = root.createTextNode(unicode(sys.argv[3]))
            tmp.replaceChild(new_child, tmp.firstChild)
            tmp = node.getElementsByTagName("location")[0]
            tmp.setAttribute("href", "repodata/" + sys.argv[3] +
                             "-primary.xml.gz")
    save_xml(root)


def main():
    xml_new = minidom.parse(sys.argv[1])
    if len(sys.argv) == 4:
        change_checksum(xml_new)
    else:
        timestamp_new = read_timestamp(xml_new)
        if len(sys.argv) == 2:
            print_files(timestamp_new)
            sys.exit(1)
        else:
            xml_old = minidom.parse(sys.argv[2])
            timestamp_old = read_timestamp(xml_old)

            if (timestamp_new['filelists'] == timestamp_old['filelists']):
                sys.exit(0)
            elif (timestamp_new['primary'] == timestamp_old['primary']):
                sys.exit(0)
            else:
                print_files(timestamp_new)
                sys.exit(1)

if __name__ == "__main__":
    main()
