# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"

options = {root: Pathname("tmp/gantt_visual"), filter: nil}
OptionParser.new do |parser|
  parser.on("--root PATH") {|path| options[:root] = Pathname(path)}
  parser.on("--filter REGEXP") {|pattern| options[:filter] = Regexp.new(pattern)}
end.parse!

pdfs = options[:root].glob("{expected,actual}/**/*.pdf").sort
pdfs.select! {|pdf| options[:filter].nil? || options[:filter].match?(pdf.to_s)}
abort "No PDFs found under #{options[:root]}" if pdfs.empty?

pdfs.each do |pdf|
  prefix = pdf.sub_ext("")
  prefix.dirname.glob("#{prefix.basename}-page-*.png").each(&:delete)
  output = "#{prefix}-page-%d.png"
  success = system(
    "gs", "-q", "-dSAFER", "-dBATCH", "-dNOPAUSE",
    "-sDEVICE=png16m", "-dTextAlphaBits=4", "-dGraphicsAlphaBits=4",
    "-r96", "-sOutputFile=#{output}", pdf.to_s
  )
  abort "Failed to rasterize #{pdf}" unless success
end

puts "Rasterized #{pdfs.length} PDFs with Ghostscript"
