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

HELP = <<~TEXT
  Usage: prep.rb <zip-path-or-url> [options]

  Prepares the product images of a WPN zip for Shopify. Each PNG is trimmed,
  gets a white margin, is made square, is limited to 2048px and is saved as a JPEG.

  Magic (default): the set code comes from the zip name and names the output
  folder, output/mtg/<SETCODE>/. Each _01/_02 pair is swapped. Files that are not
  in a complete pair are skipped.

  General (-g): every PNG is converted with its own name into
  output/general/<zip name>/. Use it for D&D, board game and other non-Magic zips.

  The default output folder is deleted and made again on each run.

  Options:
TEXT

EXAMPLES = <<~TEXT

  Examples:
    ./prep.rb ~/Downloads/tmt_pds_en.zip
    ./prep.rb -g https://media.wizards.com/2026/wpn/marketing_materials/avh/furyofdracula_pdp.zip
TEXT

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
  options = { quality: DEFAULT_QUALITY, general: false }
  parser = OptionParser.new do |o|
    o.banner = HELP
    o.on('-g', '--general', 'Convert every PNG as-is (non-Magic zips)') { options[:general] = true }
    o.on('-q', '--quality N', Integer, 'JPEG quality 1-100 (default: 85)') { |v| options[:quality] = v }
    o.on('-o', '--output DIR', 'Output directory (default: output/mtg/<SETCODE>/ or output/general/<zip name>/)') { |v| options[:output] = v }
    o.on('-h', '--help', 'Show this help') { puts o; exit }
    o.separator(EXAMPLES)
  end
  parser.parse!(args)
  source = args.shift or (puts parser; exit 1)
  [source, options]
end

def all_pngs(dir)
  Dir.children(dir).sort.map { |name| File.join(dir, name) }
end

def swapped_pairs(dir)
  stems = find_complete_pairs(dir)
  raise 'No complete _01/_02 pairs found — nothing to convert. Use -g for a non-Magic zip.' if stems.empty?

  swap_pairs(dir, stems)
end

def process_zip(zip_path, tmpdir, output_dir, quality, general:)
  png_dir = File.join(tmpdir, 'pngs')
  FileUtils.mkdir_p(png_dir)
  extract_pngs(zip_path, png_dir)
  pngs = general ? all_pngs(png_dir) : swapped_pairs(png_dir)
  convert_to_jpeg(pngs, output_dir, quality)
  puts "Done → #{output_dir}/ (#{pngs.size} JPEGs)"
end

def default_output_dir(zip_basename, general:)
  return File.join('output', 'general', File.basename(zip_basename, '.*')) if general

  File.join('output', 'mtg', derive_set_code(zip_basename))
end

def run(source, options)
  preflight
  Dir.mktmpdir do |tmpdir|
    zip_path, zip_basename = resolve_zip(source, tmpdir)
    output_dir = options[:output] || default_output_dir(zip_basename, general: options[:general])
    ensure_output_dir(output_dir, options[:output].nil?)
    process_zip(zip_path, tmpdir, output_dir, options[:quality], general: options[:general])
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
