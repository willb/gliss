require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Gliss" do
  TEST_MESSAGE = <<-END
  ===FOO=== is an example gloss of type FOO
  ===BAR=== is a gloss that 
    spans several lines
    because each line has the same
    indent 
      or at least that much
  This line does not contain a gloss.
  Neither does this one.
  ===BLAH===
    This is a gloss with nothing on the first line.
  END
  
  it "correctly identifies single-line glosses" do
    pending
  end
  
  it "correctly identifies multiple-line glosses" do
    pending
  end
  
end
