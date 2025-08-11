To embed TrueType fonts (.TTF) files, you need to extract the font metrics and 
build the required tables using the provided utility (/fonts/ttf2ufm). 

TTF2UFM is a modified version of Mark Heath's TTF 2 PT1 converter 
(http://ttf2pt1.sourceforge.net/) by Steven Wittens <steven@acko.net> 
(http://www.acko.net/blog/ufpdf). ttf2ufm, is included in /ttf2ufm-src. 
The /fonts/ttf2ufm folder contains a compiled Windows binary. 
TTF 2 UFM is identical to TTF 2 PT1 except that it also generates a .ufm file 
for usage with makefont.rb.

RBPDF Fonts

RBPDF supports TrueTypeUnicode (UTF-8 Unicode), TrueType, CID-0 and Core (standard) fonts.

There are two ways to use a new font: embedding it in the PDF (with or without subsetting) or not. When a font is not embedded, it is searched in the system. The advantage is that the PDF file is lighter; on the other hand, if it is not available, a substitution font is used. So it is preferable to ensure that the needed font is installed on the client systems. If the file is to be viewed by a large audience, it is recommended to embed.

RBPDF support font subsetting to reduce the size of documents using large unicode font files.
If you embed the whole font in the PDF, the person on the other end can make changes to it even if he didn't have your font.
If you subset the font, file size of the PDF will be smaller but the person who receives your PDF would need to have your same font in order to make changes to your PDF.
The option for enabling/disabling the font subsetting are explained on the source code documentation for methods SetFont() and AddFont(). 

The fonts that could be not embedded are only the standard core fonts and CID-0 fonts.

The PDF Core (standard) fonts are:

    * courier : Courier
    * courierb : Courier Bold
    * courierbi : Courier Bold Italic
    * courieri : Courier Italic
    * helvetica : Helvetica
    * helveticab : Helvetica Bold
    * helveticabi : Helvetica Bold Italic
    * helveticai : Helvetica Italic
    * symbol : Symbol
    * times : Times New Roman
    * timesb : Times New Roman Bold
    * timesbi : Times New Roman Bold Italic
    * timesi : Times New Roman Italic
    * zapfdingbats : Zapf Dingbats

Setting up a font for usage with RBPDF requires the following steps:

   1. Convert all font filenames to lowercase and rename using the following schema:
          * [basic-font-name-in-lowercase].ttf for regular font
          * [basic-font-name-in-lowercase]b.ttf for bold variation
          * [basic-font-name-in-lowercase]i.ttf for oblique variation
          * [basic-font-name-in-lowercase]bi.ttf for bold oblique variation

   2. Generate the font's metrics file.
          * For TrueTypeUnicode or TrueType font files, use the the provided ttf2ufm utility (fonts/utils/ttf2ufm):

            $ ttf2ufm -a -F myfont.ttf

   3. Run makefont.rb script.
          * For TrueTypeUnicode:

            $ ruby makefont.rb myfont.ttf myfont.ufm

          * For TrueType:

            $ ruby makefont.rb myfont.ttf myfont.afm

      You may also specify additional parameters:

      MakeFont(string fontfile, string fmfile [, boolean embedded [, enc="cp1252" [, patch={}]]])

          * fontfile : Path to the .ttf or .pfb file.
          * fmfile : Path to the .afm file for TrueType or .ufm for TrueTypeUnicode.
          * embedded : Set to false to not embed the font, true otherwise (default).
          * enc : Name of the encoding table to use. Default value: cp1252. Omit this parameter for TrueType Unicode and symbolic fonts like Symbol or ZapfDingBats. The encoding defines the association between a code (from 0 to 255) and a character. The first 128 are fixed and correspond to ASCII. The encodings are stored in .map files. Those available are:
                o cp1250 (Central Europe)
                o cp1251 (Cyrillic)
                o cp1252 (Western Europe)
                o cp1253 (Greek)
                o cp1254 (Turkish)
                o cp1255 (Hebrew)
                o cp1257 (Baltic)
                o cp1258 (Vietnamese)
                o cp874 (Thai)
                o iso-8859-1 (Western Europe)
                o iso-8859-2 (Central Europe)
                o iso-8859-4 (Baltic)
                o iso-8859-5 (Cyrillic)
                o iso-8859-7 (Greek)
                o iso-8859-9 (Turkish)
                o iso-8859-11 (Thai)
                o iso-8859-15 (Western Europe)
                o iso-8859-16 (Central Europe)
                o koi8-r (Russian)
                o koi8-u (Ukrainian)
            Of course, the font must contain the characters corresponding to the chosen encoding. The encodings which begin with cp are those used by Windows; Linux systems usually use ISO.
          * patch : Optional modification of the encoding. Empty by default. This parameter gives the possibility to alter the encoding. Sometimes you may want to add some characters. For instance, ISO-8859-1 does not contain the euro symbol. To add it at position 164, pass {164=>'Euro'}.

   4. Edit and copy resulting files by case:
          * For embedded fonts: copy the resulting .rb, .z and .ctg.z (if available) files to the RBPDF fonts directory.
          * For not-embedding the font, edit the .rb file and comment the font[:file] entry.
          * For CID-0 fonts (not embeddeed) you have to edit the .rb file:
                o change the font type to: font[:type]='cidfont0'
                o set the default font width by adding the line: font[:dw]=1000
                o remove the font[:enc], font[:file] and font[:ctg] variables definitions
                o add one of the following blocks of text at the end of the file (depends by the language you are using - see the cid0cs.rb/cid0ct.rb/cid0kr.rb/cid0jp.rb files for a working example):
                      + # Simplified Chinese
                        require 'fonts/uni2cid_ag15.rb'
                        include(UNI2CID_AG15)
                        font[:cidinfo]={'Registry'=>'Adobe','Ordering'=>'GB1','Supplement'=>2, 'uni2cid'=>UNI2CID}
                        font[:enc]='UniGB-UTF16-H'

                      + # Traditional Chinese
                        require 'fonts/uni2cid_ac15.rb'
                        include(UNI2CID_AC15)
                        font[:cidinfo]={'Registry'=>'Adobe','Ordering'=>'CNS1','Supplement'=>0, 'uni2cid'=>UNI2CID}
                        font[:enc]='UniCNS-UTF16-H'

                      + # Korean
                        require 'fonts/uni2cid_ak12.rb'
                        include(UNI2CID_AK12)
                        font[:cidinfo]={'Registry'=>'Adobe','Ordering'=>'Korea1','Supplement'=>0, 'uni2cid'=>UNI2CID}
                        font[:enc]='UniKS-UTF16-H'

                      + # Japanese
                        require 'fonts/uni2cid_aj16.rb'
                        include(UNI2CID_AJ16)
                        font[:cidinfo]={'Registry'=>'Adobe','Ordering'=>'Japan1','Supplement'=>5, 'uni2cid'=>UNI2CID}
                        font[:enc]='UniJIS-UTF16-H'

                o copy the .rb file to the RBPDF fonts directory.
   5. Rename rb font files variations using the following schema:
          * [basic-font-name-in-lowercase].rb for regular font
          * [basic-font-name-in-lowercase]b.rb for bold variation
          * [basic-font-name-in-lowercase]i.rb for oblique variation
          * [basic-font-name-in-lowercase]bi.rb for bold oblique variation

