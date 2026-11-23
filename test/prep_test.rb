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

  def test_general_mode_converts_every_png_with_its_own_name
    zip = write_zip('furyofdracula_pdp.zip', 'a_01.png' => png('red'), 'a_02.png' => png('blue'), 'box.png' => png('red'))

    output = convert(zip, general: true)

    assert_equal %w[a_01.jpg a_02.jpg box.jpg], Dir.children(output).sort
    assert_color RED, File.join(output, 'a_01.jpg')
  end

  def test_default_output_dir_is_the_set_code_under_mtg_and_the_zip_name_under_general
    assert_equal 'output/mtg/TMT', default_output_dir('tmt_pds_en.zip', general: false)
    assert_equal 'output/general/furyofdracula_pdp', default_output_dir('furyofdracula_pdp.zip', general: true)
  end

  def test_derive_set_code_reads_the_zip_name_and_otherwise_asks_for_three_characters
    assert_equal 'TMT', derive_set_code('tmt_pds_en.zip')
    assert_equal 'TMT', derive_set_code('MTGTMT_pds.zip')
    assert_equal 'EBR', answering("ebr\n") { derive_set_code('eberron_product_shots.zip') }
    assert_raises(RuntimeError) { answering("eberron\n") { derive_set_code('eberron_product_shots.zip') } }
  end

  def test_framing_trims_transparent_edges_adds_a_margin_squares_and_limits_to_2048
    small = frame(png('red', canvas: '100x60', box: '60,10 79,19'))
    assert_equal [22, 22], size_of(small)
    assert_color WHITE, small, at: [0, 0]
    assert_color RED, small

    large = frame(IO.popen(['magick', '-size', '3000x1000', 'xc:red', 'png:-'], 'rb', &:read))
    assert_equal [2048, 2048], size_of(large)
    assert_color RED, large, at: [100, 1024]
    assert_color RED, large, at: [1948, 1024]
    assert_color WHITE, large, at: [80, 1024]
    assert_color WHITE, large, at: [1024, 700]
  end

  private

  def frame(bytes)
    source = File.join(@dir, 'source.png')
    File.binwrite(source, bytes)
    capture_io { convert_to_jpeg([source], @dir, DEFAULT_QUALITY) }
    File.join(@dir, 'source.jpg')
  end

  def size_of(path)
    IO.popen(['magick', 'identify', '-format', '%w %h', path], &:read).split.map(&:to_i)
  end

  def convert(zip, general: false)
    output = File.join(@dir, 'output')
    work = File.join(@dir, 'work')
    FileUtils.mkdir_p([output, work])
    capture_io { process_zip(zip, work, output, DEFAULT_QUALITY, general:) }
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
    size_of(path).map { |side| side / 2 }
  end
end
