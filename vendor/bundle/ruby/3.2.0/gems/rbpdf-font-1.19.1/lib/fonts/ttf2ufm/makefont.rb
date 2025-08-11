#============================================================+
# File name   : makefont.rb
# Begin       : 2004-12-31
# Last Update : 2010-03-19
# Version     : 1.2.006
# License     : GNU LGPL (http://www.gnu.org/copyleft/lesser.html)
# 	----------------------------------------------------------------------------
# 	Copyright (C) 2008  Nicola Asuni - Tecnick.com S.r.l.
# 	
# 	This program is free software: you can redistribute it and/or modify
# 	it under the terms of the GNU Lesser General Public License as published by
# 	the Free Software Foundation, either version 2.1 of the License, or
# 	(at your option) any later version.
# 	
# 	This program is distributed in the hope that it will be useful,
# 	but WITHOUT ANY WARRANTY; without even the implied warranty of
# 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# 	GNU Lesser General Public License for more details.
# 	
# 	You should have received a copy of the GNU Lesser General Public License
# 	along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 	
# 	See LICENSE.TXT file for more information.
#  ----------------------------------------------------------------------------
#
# Description : Utility to generate font definition files for RBPDF
#
# Authors: Nicola Asuni, Olivier Plathey, Steven Wittens
#
# (c) Copyright:
#               Nicola Asuni
#               Tecnick.com S.r.l.
#               Via della Pace, 11
#               09044 Quartucciu (CA)
#               ITALY
#               www.tecnick.com
#               info@tecnick.com
#============================================================+

#
# Utility to generate font definition files fot RBPDF.
# @author Nicola Asuni, Olivier Plathey, Steven Wittens
# @copyright 2004-2008 Nicola Asuni - Tecnick.com S.r.l (www.tecnick.com) Via Della Pace, 11 - 09044 - Quartucciu (CA) - ITALY - www.tecnick.com - info@tecnick.com
# @package com.tecnick.tcpdf
# @link http://www.tcpdf.org
# @license http://www.gnu.org/copyleft/lesser.html LGPL
# 

# 
# [@param string :fontfile] path to font file (TTF, OTF or PFB).
# [@param string :fmfile] font metrics file (UFM or AFM).
# [@param boolean :embedded] Set to false to not embed the font, true otherwise (default).
# [@param string :enc] Name of the encoding table to use. Omit this parameter for TrueType Unicode, OpenType Unicode and symbolic fonts like Symbol or ZapfDingBats.
# [@param hash :patch] Optional modification of the encoding
# 
def MakeFont(fontfile, fmfile, embedded=true, enc='cp1252', patch={})
  # Generate a font definition file
  unless File.exist?(fontfile)
    abort('Error: file not found: ' + fontfile)
  end
  unless File.exist?(fmfile)
    abort('Error: file not found: ' + fmfile)
  end
  cidtogidmap = ''
  map = []
  diff = ''
  dw = 0 # default width
  ffext = fontfile[-3..-1].downcase
  fmext = fmfile[-3..-1].downcase
  type = ''
  if fmext == 'afm'
    if (ffext == 'ttf') or (ffext == 'otf')
      type = 'TrueType'
    elsif ffext == 'pfb'
      type = 'Type1'
    else
      abort('Error: unrecognized font file extension: ' + ffext)
    end
    if enc
      map = ReadMap(enc)
      patch.each {|cc, gn|
        map[cc] = gn
      }
    end
    fm, map = ReadAFM(fmfile, map)
    #if widths['.notdef']
    #  dw = widths['.notdef']
    #end
    if enc
      diff = MakeFontEncoding(map)
    end
    fd = MakeFontDescriptor(fm, map.empty?)
  elsif fmext == 'ufm'
    enc = ''
    if (ffext == 'ttf') or (ffext == 'otf')
      type = 'TrueTypeUnicode'
    else
      abort('Error: not a TrueType font: ' + ffext)
    end
    fm, cidtogidmap = ReadUFM(fmfile, cidtogidmap)
    dw = fm['MissingWidth']
    fd = MakeFontDescriptor(fm, false)
  end
  # Start generation
  basename = File.basename(fmfile, ".*").downcase
  s = 'RBPDFFontDescriptor.define(\'' + basename + "') do |font|\n"
  s << "  font[:type]='" + type + "'\n"
  s << "  font[:name]='" + fm['FontName'] + "'\n"
  s << "  font[:desc]=" + fd + "\n"
  if fm['UnderlinePosition'].nil?
    fm['UnderlinePosition'] = -100
  end
  if fm['UnderlineThickness'].nil?
    fm['UnderlineThickness'] = 50
  end
  s << "  font[:up]=" + fm['UnderlinePosition'].to_s + "\n"
  s << "  font[:ut]=" + fm['UnderlineThickness'].to_s + "\n"
  if dw <= 0
    if fm['Widths'][32] and (fm['Widths'][32].to_i > 0)
      # assign default space width
      dw = fm['Widths'][32].to_i
    else
      dw = 600
    end
  end
  s << "  font[:dw]=" + dw.to_s + "\n"
  s << "  font[:cw]=" + MakeWidthArray(fm) + "\n"
  s << "  font[:enc]='" + enc + "'\n"
  s << "  font[:diff]='" + diff + "'\n"
  if embedded
    # Embedded font
    if (type == 'TrueType') or (type == 'TrueTypeUnicode')
      CheckTTF(fontfile)
    end
    f = open(fontfile, 'rb')
    if !f
      abort('Error: Unable to open ' + fontfile)
    end
    file = f.read(File::stat(fontfile).size)
    f.close
    if type == 'Type1'
      # Find first two sections and discard third one
      header = (file[0, 1].unpack('C')[0] == 128)
      if header
        # Strip first binary header
        file = file[6,-1]
      end
      pos = file.index('eexec')
      if pos.nil?
        abort('Error: font file does not seem to be valid Type1')
      end
      size1 = pos + 6
      if header and (file{size1}.unpack('C')[0] == 128)
        # Strip second binary header
        file = file[0, size1] + file[(size1 + 6)..-1]
      end
      pos = file.index('00000000')
      if pos.nil?
        abort('Error: font file does not seem to be valid Type1')
      end
      size2 = pos - size1
      file = file[0, size1 + size2]
    end
    basename = basename.downcase
    if Object.const_defined?(:Zlib)
      cmp = basename + '.z'
      SaveToFile(cmp, Zlib::Deflate.deflate(file, 9), 'b')
      s << '  font[:file]=\'' + cmp + "'\n"
      print "Font file compressed (" + cmp + ")\n"
      unless cidtogidmap.empty?
        cmp = basename + '.ctg.z'
        SaveToFile(cmp, Zlib::Deflate.deflate(cidtogidmap, 9), 'b')
        print "CIDToGIDMap created and compressed (" + cmp + ")\n"
        s << '  font[:ctg]=\'' + cmp + "'\n"
      end
    else
      s << 'file=\'' + File.basename(fontfile, ".*") + "'\n"
      print "Notice: font file could not be compressed (zlib extension not available)\n"
      if !cidtogidmap.empty?
        cmp = basename + '.ctg'
        f = open(cmp, 'wb')
        f.write(cidtogidmap)
        f.close
        print "CIDToGIDMap created (" + cmp + ")\n"
        s << '  font[:ctg]=\'' + cmp + "'\n"
      end
    end
    if type == 'Type1'
      s << '  font[:size1]=' + size1 + "\n"
      s << '  font[:size2]=' + size2 + "\n"
    else
      s << '  font[:originalsize]=' + File::stat(fontfile).size.to_s + "\n"
    end
  else
    # Not embedded font
    s << '  font[:file]=' + "''\n"
  end
  s << "end\n"
  SaveToFile(basename + '.rb',s)
  print "Font definition file generated (" + basename + ".rb)\n"
end

#
# Read the specified encoding map.
# [@param string :enc] map name (see /enc/ folder for valid names).
# [@return array]
#
def ReadMap(enc) 
  # Read a map file
  file = File.dirname(__FILE__) + '/enc/' + enc.downcase + '.map'
  a = File.open(file).readlines
  if a.empty?
    abort('Error: encoding not found: ' + enc)
  end
#puts a.length
  cc2gn = []
  a.each {|l|
    if l[0, 1] == '!'
#puts l
      e = l.rstrip.split(/[ \t]+/)
      cc = e[0][1..-1].hex
      gn = e[2]
      cc2gn[cc] = gn
    end
  }
  256.times {|i|
    if cc2gn[i].nil?
      cc2gn[i] = '.notdef'
    end
  }
  return cc2gn
end

#
# Read UFM file
# [@return hash :fm]
# [@return string :cidtogidmap]
#
def ReadUFM(file, cidtogidmap)
  # Prepare empty CIDToGIDMap
  cidtogidmap = ''.ljust(256 * 256 * 2, "\x00")
  # Read a font metric file
  a = File.open(file).readlines
  if a.empty?
    abort('File not found')
  end
  widths = {}
  fm = {}
  a.each {|l|
    e = l.rstrip.split(' ')
    if e.length < 2
      next
    end
    code = e[0]
    param = e[1]
    if code == 'U'
      # U 827 ; WX 0 ; N squaresubnosp ; G 675 
      # Character metrics
      cc = e[1].to_i
      if cc != -1
        gn = e[7]
        w = e[4].to_i
        glyph = e[10].to_i
        widths[cc] = w
        if cc == 'X'.unpack('C')[0]
          fm['CapXHeight'] = e[13]
        end
        # Set GID
        if (cc >= 0) and (cc < 0xFFFF) and glyph
          cidtogidmap[cc * 2, 1] = (glyph >> 8).chr
          cidtogidmap[cc * 2 + 1, 1] = (glyph & 0xFF).chr
        end
      end
      if (gn and (gn == '.notdef')) and fm['MissingWidth'].nil?
        fm['MissingWidth'] = w
      end
    elsif code == 'FontName'
      fm['FontName'] = param
    elsif code == 'Weight'
      fm['Weight'] = param
    elsif code == 'ItalicAngle'
      fm['ItalicAngle'] = param.to_f
    elsif code == 'Ascender'
      fm['Ascender'] = param.to_i
    elsif code == 'Descender'
      fm['Descender'] = param.to_i
    elsif code == 'UnderlineThickness'
      fm['UnderlineThickness'] = param.to_i
    elsif code == 'UnderlinePosition'
      fm['UnderlinePosition'] = param.to_i
    elsif code == 'IsFixedPitch'
      fm['IsFixedPitch'] = (param == 'true')
    elsif code == 'FontBBox'
      fm['FontBBox'] = [e[1], e[2], e[3], e[4]]
    elsif code == 'CapHeight'
      fm['CapHeight'] = param.to_i
    elsif code == 'StdVW'
      fm['StdVW'] = param.to_i
    end
  }
  if fm['MissingWidth'].nil?
    fm['MissingWidth'] = 600
  end
  if fm['FontName'].nil?
    abort('FontName not found')
  end
  fm['Widths'] = widths
  return fm, cidtogidmap
end

#
# Read AFM file
# [@return hash :fm]
# [@return array :map]
#
def ReadAFM(file, map)
  # Read a font metric file
  a = File.open(file).readlines
  if a.empty?
    abort('File not found')
  end
  widths = {}
  fm = {}
  fix = {
    'Edot'=>'Edotaccent',
    'edot'=>'edotaccent',
    'Idot'=>'Idotaccent',
    'Zdot'=>'Zdotaccent',
    'zdot'=>'zdotaccent',
    'Odblacute' => 'Ohungarumlaut',
    'odblacute' => 'ohungarumlaut',
    'Udblacute'=>'Uhungarumlaut',
    'udblacute'=>'uhungarumlaut',
    'Gcedilla'=>'Gcommaaccent',
    'gcedilla'=>'gcommaaccent',
    'Kcedilla'=>'Kcommaaccent',
    'kcedilla'=>'kcommaaccent',
    'Lcedilla'=>'Lcommaaccent',
    'lcedilla'=>'lcommaaccent',
    'Ncedilla'=>'Ncommaaccent',
    'ncedilla'=>'ncommaaccent',
    'Rcedilla'=>'Rcommaaccent',
    'rcedilla'=>'rcommaaccent',
    'Scedilla'=>'Scommaaccent',
    'scedilla'=>'scommaaccent',
    'Tcedilla'=>'Tcommaaccent',
    'tcedilla'=>'tcommaaccent',
    'Dslash'=>'Dcroat',
    'dslash'=>'dcroat',
    'Dmacron'=>'Dcroat',
    'dmacron'=>'dcroat',
    'combininggraveaccent'=>'gravecomb',
    'combininghookabove'=>'hookabovecomb',
    'combiningtildeaccent'=>'tildecomb',
    'combiningacuteaccent'=>'acutecomb',
    'combiningdotbelow'=>'dotbelowcomb',
    'dongsign'=>'dong'
    }
  a.each {|l|
    e = l.rstrip.split(' ')
    if e.length < 2
      next
    end
    code = e[0]
    param = e[1]
    if code == 'C'
      # Character metrics
      cc = e[1].to_i
      w = e[4]
      gn = e[7]
      if gn[-4..-1] == '20AC'
        gn = 'Euro'
      end
      if fix[gn]
        # Fix incorrect glyph name
        map.each_with_index {|n, c|
          if n == fix[gn]
            map[c] = gn
          end
        }
      end
      if map.empty?
        # Symbolic font: use built-in encoding
        widths[cc] = w
      else
        widths[gn] = w
        if gn == 'X'
          fm['CapXHeight'] = e[13]
        end
      end
      if gn == '.notdef'
        fm['MissingWidth'] = w
      end
    elsif code == 'FontName'
      fm['FontName'] = param
    elsif code == 'Weight'
      fm['Weight'] = param
    elsif code == 'ItalicAngle'
      fm['ItalicAngle'] = param.to_f
    elsif code == 'Ascender'
      fm['Ascender'] = param.to_i
    elsif code == 'Descender'
      fm['Descender'] = param.to_i
    elsif code == 'UnderlineThickness'
      fm['UnderlineThickness'] = param.to_i
    elsif code == 'UnderlinePosition'
      fm['UnderlinePosition'] = param.to_i
    elsif code == 'IsFixedPitch'
      fm['IsFixedPitch'] = (param == 'true')
    elsif code == 'FontBBox'
      fm['FontBBox'] = [e[1], e[2], e[3], e[4]]
    elsif code == 'CapHeight'
      fm['CapHeight'] = param.to_i
    elsif code == 'StdVW'
      fm['StdVW'] = param.to_i
    end
  }
  if fm['FontName'].nil?
    abort('FontName not found')
  end
  if !map.empty?
    if widths['.notdef'].nil?
      widths['.notdef'] = 600
    end
    if widths['Delta'].nil? and widths['increment']
      widths['Delta'] = widths['increment']
    end
    # Order widths according to map
    256.times {|i|
      if widths[map[i]].nil?
        print "Warning: character " + map[i] + " is missing\n"
        widths[i] = widths['.notdef']
      else
        widths[i] = widths[map[i]]
      end
    }
  end
  fm['Widths'] = widths
  return fm, map
end

def MakeFontDescriptor(fm, symbolic=false)
  # Ascent
  asc = fm['Ascender'] ? fm['Ascender'] : 1000
  fd = "{'Ascent'=>" + asc.to_s
  # Descent
  desc = fm['Descender'] ? fm['Descender'] : -200
  fd << ",'Descent'=>" + desc.to_s
  # CapHeight
  if fm['CapHeight']
    ch = fm['CapHeight']
  elsif fm['CapXHeight']
    ch = fm['CapXHeight']
  else
    ch = asc
  end
  fd << ",'CapHeight'=>" + ch.to_s
  # Flags
  flags = 0
  if fm['IsFixedPitch'] and (fm['IsFixedPitch'] == true)
    flags += 1<<0
  end
  if symbolic
    flags += 1<<2
  else
    flags += 1<<5
  end
  if fm['ItalicAngle'] and (fm['ItalicAngle'] != 0)
    flags += 1<<6
  end
  fd << ",'Flags'=>" + flags.to_s
  # FontBBox
  if fm['FontBBox']
    fbb = fm['FontBBox']
  else
    fbb = [0, desc - 100, 1000, asc + 100]
  end
  fd << ",'FontBBox'=>'[" + fbb[0].to_s + ' ' + fbb[1].to_s + ' ' + fbb[2].to_s + ' ' + fbb[3].to_s + "]'"
  # ItalicAngle
  ia = fm['ItalicAngle'] ? fm['ItalicAngle'] : 0
  fd << ",'ItalicAngle'=>" + ia.to_s
  # StemV
  if fm['StdVW']
    stemv = fm['StdVW']
  elsif fm['Weight'] and fm['Weight'] =~ /(bold|black)/i
    stemv = 120
  else
    stemv = 70
  end
  fd << ",'StemV'=>" + stemv.to_s
  # MissingWidth
  if fm['MissingWidth']
    fd << ",'MissingWidth'=>" + fm['MissingWidth'].to_s
  end
  fd << '}'
  return fd
end

def MakeWidthArray(fm)
  # Make character width array
  s = '{'
  cw = fm['Widths']
  els = []
  c = -1
  cw.each{|i,w|
    if i.is_a? Integer
      els.push(((((c += 1) % 10) == 0) ? "\n  " : '') + i.to_s + '=>' + w.to_s)
    end
  }
  s << els.join(',')
  s << '}'
  return s
end

def MakeFontEncoding(map)
  # Build differences from reference encoding
  ref = ReadMap('cp1252')
  s = ''
  last = 0
  32.upto(255) {|i|
    if map[i] != ref[i]
      if i != last + 1
        s << i.to_s + ' '
      end
      last = i
      s << '/' + map[i] + ' '
    end
  }
  return s.rstrip
end

def SaveToFile(file, s, mode='b')
  f = open(file, 'w' + mode)
  if !f
    abort('Can\'t write to file ' + file)
  end
  f.write(s)
  f.close
end

def ReadShort(f)
  a = f.read(2).unpack('n1')
  return a[0]
end

def ReadLong(f)
  a = f.read(4).unpack('N1')
  return a[0]
end

def CheckTTF(file)
  # Check if font license allows embedding
  f = open(file, 'rb')
  if !f
    abort('Error: unable to open ' + file)
  end
  # Extract number of tables
  f.seek(4, IO::SEEK_CUR)
  nb = ReadShort(f)
  f.seek(6, IO::SEEK_CUR)
  # Seek OS/2 table
  found = false
  nb.times {|i|
    if f.read(4) == 'OS/2'
      found = true
      break
    end
    f.seek(12, IO::SEEK_CUR)
  }
  if !found
    f.close
    return
  end
  f.seek(4, IO::SEEK_CUR)
  offset = ReadLong(f)
  f.seek(offset, IO::SEEK_SET)
  # Extract fsType flags
  f.seek(8, IO::SEEK_CUR)
  fsType = ReadShort(f)
  rl = (fsType & 0x02) != 0
  pp = (fsType & 0x04) != 0
  e = (fsType & 0x08) != 0
  f.close
  if rl and !pp and !e
    print "Warning: font license does not allow embedding\n"
  end
end

if RUBY_VERSION < '1.9'
  abort("Error: Ruby 1.8.7 not supported.")
end

require 'zlib'

arg = ARGV.dup
if arg.length >= 2
  if arg.length == 3
    arg[3] = arg[2]
    arg[2] = true
  else
    if arg[2].nil?
      arg[2] = true
    end
    if arg[3].nil?
      arg[3] = 'cp1252'
    end
  end
  if arg[4].nil?
    arg[4] = {}
  else
    arg[4] = eval(ARGV[4])
  end
  MakeFont(arg[0], arg[1], arg[2], arg[3], arg[4])
else
  print "Usage: makefont.rb <ttf/otf/pfb file> <afm/ufm file> <encoding> <patch>\n"
end

