require_relative '../prep'
require 'minitest/autorun'
require 'stringio'

class PrepTest < Minitest::Test
  RED = [255, 0, 0].freeze
  BLUE = [0, 0, 255].freeze
  WHITE = [255, 255, 255].freeze

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_magic_keeps_only_complete_pairs_and_swaps_them
    zip = write_zip('MTGTMT_pds.zip',
                    'set/a_01.png' => png('red'), 'set/a_02.png' => png('blue'),
                    'set/b_01.png' => png('red'), 'set/box.png' => png('red'),
                    'set/details.docx' => 'not an image',
                    '__MACOSX/set/c_01.png' => png('red'), '__MACOSX/set/c_02.png' => png('red'),
                    'set/.d_01.png' => png('red'), 'set/.d_02.png' => png('red'))

    output = convert(zip)

    assert_equal %w[a_01.jpg a_02.jpg], Dir.children(output).sort
    assert_color BLUE, File.join(output, 'a_01.jpg')
    assert_color RED, File.join(output, 'a_02.jpg')
  end

  def test_derive_set_code_reads_the_zip_name_and_otherwise_asks_for_three_characters
    assert_equal 'TMT', derive_set_code('tmt_pds_en.zip')
    assert_equal 'TMT', derive_set_code('MTGTMT_pds.zip')
    assert_equal 'EBR', answering("ebr\n") { derive_set_code('eberron_product_shots.zip') }
    assert_raises(RuntimeError) { answering("eberron\n") { derive_set_code('eberron_product_shots.zip') } }
  end

  private

  def convert(zip)
    output = File.join(@dir, 'output')
    work = File.join(@dir, 'work')
    FileUtils.mkdir_p([output, work])
    capture_io { process_zip(zip, work, output, DEFAULT_QUALITY) }
    output
  end

  def write_zip(name, entries)
    path = File.join(@dir, name)
    Zip::File.open(path, create: true) do |zip|
      entries.each { |entry, bytes| zip.get_output_stream(entry) { |io| io.write(bytes) } }
    end
    path
  end

  def png(color, canvas: '40x30', box: '10,5 29,24')
    IO.popen(['magick', '-size', canvas, 'xc:none', '-fill', color, '-draw', "rectangle #{box}", 'png:-'], 'rb', &:read)
  end

  def answering(text)
    result = nil
    $stdin = StringIO.new(text)
    capture_io { result = yield }
    result
  ensure
    $stdin = STDIN
  end

  def assert_color(expected, path, at: nil)
    x, y = at || center_of(path)
    pixel = IO.popen(['magick', path, '-crop', "1x1+#{x}+#{y}", '+repage', '-depth', '8', 'txt:-'], &:read)
    actual = pixel[/\((\d+),(\d+),(\d+)/, 0].delete('(').split(',').map(&:to_i)
    assert expected.zip(actual).all? { |want, got| (want - got).abs <= 16 }, "Expected #{expected} at #{x},#{y} in #{File.basename(path)}, got #{actual}"
  end

  def center_of(path)
    IO.popen(['magick', 'identify', '-format', '%w %h', path], &:read).split.map { |side| side.to_i / 2 }
  end
end
