<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
  <!ENTITY % html "IGNORE">
  <![%html; [
	<!ENTITY % print "IGNORE">
	<!ENTITY docbook.dsl PUBLIC "-//Norman Walsh//DOCUMENT DocBook HTML Stylesheet//EN" CDATA dsssl>
  ]]>

  <!ENTITY % print "INCLUDE">
  <![%print; [
	<!ENTITY docbook.dsl PUBLIC "-//Norman Walsh//DOCUMENT DocBook Print Stylesheet//EN" CDATA dsssl>
  ]]>
]>

<!-- This is (or was) the standard Cygnus DocBook-utils Style Sheet for DocBook
     Eric Bischoff <eric@caldera.de>

Options added:

%paper-type%: A4
%shade-verbatim%: true
%funcsynopsis-decoration%: true

-->

<style-sheet>

	<style-specification id="utils" use="docbook">
		<style-specification-body>

		;; ===================================================================
		;; Generic Parameters
		;; (Generic currently means: both print and html)

		(define %chapter-autolabel% #t)
		(define %section-autolabel% #t)
		(define (toc-depth nd) 3)

		;; make funcsynopsis look pretty
		(define %funcsynopsis-decoration%
		  ;; Decorate elements of a FuncSynopsis?
		  #t)
		</style-specification-body>
	</style-specification>

	<style-specification id="print" use="utils">
		<style-specification-body>

		;; ===================================================================
		;; Print Parameters
		;; Call: jade -d docbook-utils.dsl#print

		; === Page layout ===
		(define %paper-type% "A4")		;; use A4 paper - comment this out if needed

		; === Media objects ===
		(define preferred-mediaobject-extensions  ;; this magic allows to use different graphical
			(list "eps"))			;;   formats for printing and putting online
		(define acceptable-mediaobject-extensions
			'())
		(define preferred-mediaobject-notations
			(list "EPS"))
		(define acceptable-mediaobject-notations
			(list "linespecific"))

		; === Rendering ===
		(define %head-after-factor% 0.2)	;; not much whitespace after orderedlist head
		(define ($paragraph$)			;; more whitespace after paragraph than before
			(make paragraph
				first-line-start-indent: (if (is-first-para)
							%para-indent-firstpara%
							%para-indent%
				)
				space-before: (* %para-sep% 4)
				space-after: (/ %para-sep% 4)
				quadding: %default-quadding%
				hyphenate?: %hyphenation%
				language: (dsssl-language-code)
				(process-children)
			)
		)


		;; Line break
		(element LITERALLAYOUT (make paragraph-break))

		</style-specification-body>
	</style-specification>

	<style-specification id="html" use="utils">
		<style-specification-body>

		;; ===================================================================
		;; HTML Parameters
		;; Call: jade -d docbook-utils.dsl#html

		; === File names ===
		(define %root-filename% "index")	;; name for the root html file
		(define %html-ext% ".html")		;; default extension for html output files
		(define %html-prefix% "")               ;; prefix for all filenames generated (except root)
		(define %use-id-as-filename% #f)        ;; if #t uses ID value, if present, as filename
							;;   otherwise a code is used to indicate level
							;;   of chunk, and general element number
							;;   (nth element in the document)
		(define use-output-dir #f)              ;; output in separate directory?
		(define %output-dir% "HTML")            ;; if output in directory, it's called HTML

		; === HTML settings ===
		(define %html-pubid% "-//W3C//DTD HTML 4.01 Transitional//EN") ;; Nearly true :-(
		(define %html40% #t)

		; === Media objects ===
		(define preferred-mediaobject-extensions  ;; this magic allows to use different graphical
			(list "png" "jpg" "jpeg"))		;;   formats for printing and putting online
		(define acceptable-mediaobject-extensions
			(list "bmp" "gif" "eps" "epsf" "avi" "mpg" "mpeg" "qt"))
		(define preferred-mediaobject-notations
			(list "PNG" "JPG" "JPEG"))
		(define acceptable-mediaobject-notations
			(list "EPS" "BMP" "GIF" "linespecific"))
		; === Rendering ===
		(define %admon-graphics% #t)		;; use symbols for Caution|Important|Note|Tip|Warning

		; === Books only ===
		(define %generate-book-titlepage% #t)
		(define %generate-book-toc% #t)
		(define ($generate-chapter-toc$) #f)	;; never generate a chapter TOC in books

		; === Articles only ===
		(define %generate-article-titlepage% #t)
		(define %generate-article-toc% #t)      ;; make TOC

		(define %shade-verbatim% #t)

		</style-specification-body>
	</style-specification>

	<external-specification id="docbook" document="docbook.dsl">

</style-sheet>
