#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'optparse'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'zip'

$stdout.sync = true

DEFAULT_QUALITY = 85

def preflight
  missing = %w[magick curl].reject { |t| system("command -v #{t} > /dev/null 2>&1") }
  raise "Required CLI(s) not found on PATH: #{missing.join(', ')}" if missing.any?
end

def resolve_zip(source, tmpdir)
  return [source, File.basename(source)] if File.file?(source)

  basename = File.basename(URI(source).path)
  dest = File.join(tmpdir, basename)
  puts "Downloading #{basename}"
  system('curl', '-fL', '--progress-bar', '-o', dest, source, exception: true)
  [dest, basename]
end

def derive_set_code(zip_basename)
  stem = zip_basename.sub(/\.zip\z/i, '').split('_').first.to_s
  return stem.upcase if stem.length == 3
  return stem[3, 3].upcase if stem.start_with?('MTG') && stem.length >= 6

  prompt_set_code(stem)
end

def prompt_set_code(guess)
  print "Couldn't derive 3-letter set code from '#{guess}'. Enter set code: "
  input = $stdin.gets&.strip.to_s
  raise 'Set code must be 3 characters' unless input.length == 3

  input.upcase
end

def ensure_output_dir(path, is_default)
  FileUtils.rm_rf(path) if is_default && Dir.exist?(path)
  FileUtils.mkdir_p(path)
end

def extract_pngs(zip_path, dest)
  count = 0
  Zip::File.open(zip_path) do |zip|
    zip.each do |entry|
      next unless entry.name.end_with?('.png')
      next if entry.name.include?('__MACOSX')

      basename = File.basename(entry.name)
      next if basename.start_with?('.')

      File.binwrite(File.join(dest, basename), entry.get_input_stream.read)
      count += 1
    end
  end
  raise 'No PNG entries found in zip' if count.zero?

  puts "Extracting #{count} PNGs"
end

def find_complete_pairs(dir)
  pngs = Dir.children(dir).select { |n| n.end_with?('.png') }
  with_suffix = pngs.select { |n| n.match?(/_0[12]\.png\z/) }
  stems = with_suffix.map { |n| n.sub(/_0[12]\.png\z/, '') }.uniq
  stems.select do |stem|
    with_suffix.include?("#{stem}_01.png") && with_suffix.include?("#{stem}_02.png")
  end
end

def swap_pairs(dir, stems)
  stems.each do |stem|
    a = File.join(dir, "#{stem}_01.png")
    b = File.join(dir, "#{stem}_02.png")
    tmp = File.join(dir, "#{stem}_TMP.png")
    File.rename(a, tmp)
    File.rename(b, a)
    File.rename(tmp, b)
  end
  puts "Swapping #{stems.size} pairs"
  stems.flat_map { |s| [File.join(dir, "#{s}_01.png"), File.join(dir, "#{s}_02.png")] }
end

def convert_to_jpeg(pngs, output_dir, quality)
  puts 'Converting:'
  pngs.each_with_index do |src, i|
    dest = File.join(output_dir, "#{File.basename(src, '.png')}.jpg")
    system('magick', src,
           '-bordercolor', 'none', '-border', '1', '-trim', '+repage',
           '-background', 'white', '-gravity', 'center',
           '-extent', '%[fx:max(w,h)*1.1]x%[fx:max(w,h)*1.1]',
           '-flatten', '-resize', '2048x2048>', '-quality', quality.to_s,
           dest, exception: true)
    printf("  [%2d/%d] %s\n", i + 1, pngs.size, File.basename(dest))
  end
end

def parse_options(args)
  options = { quality: DEFAULT_QUALITY }
  parser = OptionParser.new do |o|
    o.banner = 'Usage: prep.rb <zip-path-or-url> [options]'
    o.on('-q', '--quality N', Integer, 'JPEG quality 1-100 (default: 85)') { |v| options[:quality] = v }
    o.on('-o', '--output DIR', 'Output directory (default: output/<SETCODE>/)') { |v| options[:output] = v }
    o.on('-h', '--help') { puts o; exit }
  end
  parser.parse!(args)
  source = args.shift or (puts parser; exit 1)
  [source, options]
end

def process_zip(zip_path, tmpdir, output_dir, quality)
  png_dir = File.join(tmpdir, 'pngs')
  FileUtils.mkdir_p(png_dir)
  extract_pngs(zip_path, png_dir)
  stems = find_complete_pairs(png_dir)
  raise 'No complete _01/_02 pairs found — nothing to convert' if stems.empty?

  paired_files = swap_pairs(png_dir, stems)
  convert_to_jpeg(paired_files, output_dir, quality)
  puts "Done → #{output_dir}/ (#{paired_files.size} JPEGs)"
end

def run(source, options)
  preflight
  Dir.mktmpdir do |tmpdir|
    zip_path, zip_basename = resolve_zip(source, tmpdir)
    set_code = derive_set_code(zip_basename)
    output_dir = options[:output] || File.join('output', set_code)
    ensure_output_dir(output_dir, options[:output].nil?)
    process_zip(zip_path, tmpdir, output_dir, options[:quality])
  end
end

def main
  source, options = parse_options(ARGV)
  run(source, options)
end

if __FILE__ == $PROGRAM_NAME
  begin
    main
  rescue Interrupt
    warn "\nAborted."
    exit 130
  rescue => e
    warn "Error: #{e.message}"
    exit 1
  end
end
