module Helpers
  extend self

  def truncate(text : String, length : Int32 = 30, omission : String = "...") : String
    if text.size > length
      stop = length - omission.size
      stop = 0 if stop < 0
      text[0...stop] + omission
    else
      text
    end
  end
end
