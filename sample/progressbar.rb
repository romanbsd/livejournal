class ProgressBar
  def initialize(caption)
    @cur = 0
    @width = 40
    print caption
    print("[" + " "*40 + "]" + "\x08"*41)
    $stdout.flush
  end

  def fill_to(pos)
    dots = pos - @cur
    print "."*dots
    $stdout.flush
    @cur = pos
  end

  def update(cur, max)
    if max > 0
      fill_to(@width*cur/max)
    else
      fill_to(@width)
    end
  end

  def finish(error=false)
    return unless @cur >= 0
    fill_to(@width) unless error
    puts
    @cur = -1
  end

  def self.with_progress(caption)
    bar = ProgressBar.new(caption)
    begin
      yield bar
    rescue => e
      bar.finish(true)
      raise e
    else
      bar.finish(false)
    end
  end
end

# vim: ts=2 sw=2 et :
