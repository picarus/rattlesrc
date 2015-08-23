# For incremental fixes, update the insignificant version number. For
# a release to CRAN bump the minor version number, for a major change,
# increment the major version number. Each incremental change is
# recorded in package/inst/NEWS.

APP=rattle
VER=3.5.7

DATE=$(shell date +%Y-%m-%d)
REPOSITORY=repository
RSITELIB=$(shell Rscript -e "cat(installed.packages()['$(APP)','LibPath'])")

help:
	@echo "Manage the $(APP) R package\n\
	============================\n\n\
	rebuild\t\tBuild and install the package.\n\
	  build  \t  Generate $(APP)_$(VER).tar.gz\n\
	  install\t  Install on the local machine\n\
	  test   \t  Start up rattle to test it\n\
	  zip    \t  Create a binary zip package\n\n\
	check\t\tCheck for issues with the packaging\n\n\
	dist\t\tUpdate files on /var/www/ and rattle.togaware.com\n\
	  src    \t  Create src packages (zip and tar).\n\
	  access \t  Copy src to access.togaware.com\n\
	  repo   \t  Update the repository at rattle.togaware.com.\n\n\
	support\t\tMiscellaneous support functions\n\
	  weather\t  Update the weather datasets from BoM\n\
	  translate\t  Regenerate translations files.\n\
	  home   \t  Update www information\n\n\
	  ucheck \t  Send to Uwe for checking MS/Windows\n\
	  cran   \t  Submit to CRAN or visit http://cran.r-project.org/submit.html\n\n\
	  clean  \t  Clean up.\n\
	  realclean\t  Extra clean.\n\n\
	RSITELIB is $(RSITELIB)\n\
	"

######################################################################
# R Package Management

.PHONY: version
version:
	perl -pi -e 's|^Version: .*|Version: $(VER)|' package/DESCRIPTION
	perl -pi -e 's|^Date: .*|Date: $(DATE)|' package/DESCRIPTION
	perl -pi -e 's|^VERSION <- .*|VERSION <- "$(VER)"|' package/R/rattle.R
	perl -pi -e 's|^DATE <- .*|DATE <- "$(DATE)"|' package/R/rattle.R

.PHONY: check
check: clean version build
	R-devel CMD check --as-cran --check-subdirs=yes $(APP)_$(VER).tar.gz

.PHONY: build
build: version $(APP)_$(VER).tar.gz

.PHONY: rebuild
rebuild: build install

.PHONY: install
install: build
	R CMD INSTALL $(APP)_$(VER).tar.gz

.PHONY: test
test: install
	Rscript -e 'library(rattle);rattle();Sys.sleep(120)'

$(APP)_$(VER).tar.gz: package/*
	R CMD build package

$(APP)_$(VER).check: $(APP)_$(VER).tar.gz
	R CMD check --as-cran --check-subdirs=yes $^

.PHONY: ucheck
ucheck: $(APP)_$(VER).tar.gz
	sh ./upload_uwe.sh
	@echo Wait for email from Uwe Legge.

.PHONY: cran
cran: $(APP)_$(VER).tar.gz
	sh ./upload_cran.sh
	@echo Be sure to email cran@r-project.org.

########################################################################
# Source code management and distribution.

.PHONY: dist
dist: home access repo version

.PHONY: home
home:
	(cd /home/gjw/projects/togaware/www/;\
	 perl -pi -e "s|Version [0-9\.]* |Version $(VER) |" \
			rattle.html.in;\
	 perl -pi -e "s|access/rattle_[0-9\.]*.tar.gz|access/rattle_$(VER).tar.gz|" \
			rattle.html.in;\
	 perl -pi -e "s| dated [^\.]*\.| dated $(DATE).|" \
			rattle.html.in;\
	 make rattle)

.PHONY: access
access: src zip
	chmod 0644 $(APP)_$(VER)_src.zip $(APP)_$(VER)_src.tar.gz \
		   $(APP)_$(VER).tar.gz $(APP)_$(VER).zip
	rsync -ahv $(APP)_$(VER)_src.zip $(APP)_$(VER)_src.tar.gz \
		   $(APP)_$(VER).tar.gz $(APP)_$(VER).zip \
		   togaware.com:webapps/access/

.PHONY: repo
repo: build zip
	cp $(APP)_$(VER).tar.gz $(APP)_$(VER).zip $(REPOSITORY)
	-R --no-save < repository/repository.R
	chmod go+r $(REPOSITORY)/*
	rsync -ahv repository/ togaware.com:webapps/rattle/src/contrib
	rsync -ahv repository/*.zip togaware.com:webapps/rattle/bin/windows/contrib/3.0/
	rsync -ahv repository/PACKAGE* togaware.com:webapps/rattle/bin/windows/contrib/3.0/
	rsync -ahv repository/*.zip togaware.com:webapps/rattle/bin/windows/contrib/3.1/
	rsync -ahv repository/PACKAGE* togaware.com:webapps/rattle/bin/windows/contrib/3.1/

.PHONY: src
src: $(APP)_$(VER)_src.zip  $(APP)_$(VER)_src.tar.gz

.PHONY: zip
zip: $(APP)_$(VER).zip

$(APP)_$(VER)_src.zip: Makefile package
	zip -r $(APP)_$(VER)_src.zip $^ -x package/*/*~

$(APP)_$(VER)_src.tar.gz: Makefile package
	(cd ..; tar zcvf rattle/$(APP)_$(VER)_src.tar.gz $(addprefix rattle/,$^) --exclude="*~")

$(APP)_$(VER).zip: install
	(cd $(RSITELIB); zip -r9 - $(APP)) >| $(APP)_$(VER).zip

########################################################################
# Misc

.PHONY: weather
weather: 
	(cd weather; make all)

.PHONY: clean
clean:
	@rm -vf package/*/*~
	@rm -vf package/*/.Rhistory
	@rm -rf package.Rcheck rattle.Rcheck

.PHONY: realclean
realclean: clean
	-@mv -v $(APP)_* BACKUP/

########################################################################
# Version Control - bzr

status:
	bzr status -V

info:
	bzr info

update:
	bzr update

diff:
	bzr diff

log:
	bzr log -l 5 -v

######################################################################
# Knitting

%.tex: %.Rnw
	R -e "knitr::knit('$<')"

%.pdf: %.tex
	rubber --pdf $*

.PHONY: %.view
%.view: %.pdf
	evince $<

%.R: %.Rnw
	R -e "knitr::purl('$<')"

