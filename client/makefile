DNF_PATH		:= /usr/bin/dnf
INSTALL_PATH 	:= /usr/lib/python3.4/site-packages/dnf-plugins
FILE_NAME 		:= dnf_zsync.py
FILE_PATH 		:= .

.PHONY: install uninstall test

install: ${INSTALL_PATH}/${FILE_NAME}

test: ${INSTALL_PATH}/${FILE_NAME}
	@sudo ${DNF_PATH} update --assumeno

${INSTALL_PATH}/${FILE_NAME}: ${FILE_PATH}/${FILE_NAME}
	@sudo cp ${FILE_PATH}/${FILE_NAME} ${INSTALL_PATH}

uninstall:
	-sudo rm ${INSTALL_PATH}/${FILE_NAME}
