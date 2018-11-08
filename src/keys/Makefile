############################################################ IDENT(1)
#
# $Title: Makefile to produce strong ssh(1) private/public key pairs $
# $Copyright: 2015-2018 Devin Teske. All rights reserved. $
# $Header: /cvsroot/druidbsd/secure_thumb/Makefile.keys,v 1.1 2015/09/15 16:21:37 devinteske Exp $
# $FrauBSD: secure_thumb/src/keys/Makefile 2018-11-08 11:58:27 -0800 freebsdfrau $
#
############################################################ CONFIGURATION

KEYGEN_ARGS=	-b 4096 -t rsa $${COMMENT:+-C "$$COMMENT"}

############################################################ TARGETS

.PHONY: all

all:
	@read -p "New key suffix [id_rsa.*]: " SUFFIX REST_IGNORED; \
	 [ "$$SUFFIX" ] || { echo "No suffix provided!"; exit 1; }; \
	 FILE="id_rsa.$$SUFFIX"; echo "Generating $$FILE";          \
	 read -p "Enter optional comment for public key: " COMMENT; \
	 sudo=; [ -w . ] || sudo=sudo;                              \
	 $$sudo ssh-keygen $(KEYGEN_ARGS) -f "$$FILE";              \
	 $$sudo chmod -w "$$FILE" "$$FILE.pub"; chmod go-r "$$FILE.pub"

################################################################################
# END
################################################################################
