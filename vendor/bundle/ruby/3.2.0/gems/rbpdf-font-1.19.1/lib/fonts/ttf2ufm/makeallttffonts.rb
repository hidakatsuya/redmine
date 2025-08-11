#============================================================+
# File name   : makeallttffonts.rb
# Begin       : 2015-09-20
# Last Update : 2015-09-20
# License     : GNU LGPL (http://www.gnu.org/copyleft/lesser.html)
#  ----------------------------------------------------------------------------
#      This program is free software: you can redistribute it and/or modify
#      it under the terms of the GNU Lesser General Public License as published by
#      the Free Software Foundation, either version 2.1 of the License, or
#      (at your option) any later version.
#
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU Lesser General Public License for more details.
#
#      You should have received a copy of the GNU Lesser General Public License
#      along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  ----------------------------------------------------------------------------
# Description : Process all TTF files on current directory to 
#               build RBPDF compatible font files.
#
# Author: Jun NAITOH
#============================================================+

#
# Process all TTF files on current directory to build RBPDF compatible font files.
# @license http://www.gnu.org/copyleft/gpl.html GNU General Public License
#

if RUBY_VERSION < '1.9'
  abort("Error: Ruby 1.8.7 not supported.")
end

require "open3"

# read directory for files (only graphics files).
Dir.glob("*ttf").each{|file|
  basename = File.basename(file, ".*")
  o, s = Open3.capture2('./ttf2ufm -a -F ' + file)
  puts o
  o, s = Open3.capture2('ruby makefont.rb ' + file + ' ' + basename + '.ufm')
  puts o
}

#============================================================+
# END OF FILE                                                 
#============================================================+
