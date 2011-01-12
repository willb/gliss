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
:::ARGH::: argh is a gloss with a different delimiter character.
---cruft---
  
  This is a gloss in paragraph format.
  This is a good format for longer comments.
END
  
  before(:each) do
    @glosses = Gliss.glosses_in(TEST_MESSAGE)
  end
  
  it "correctly identifies single-line glosses" do
    @glosses.select {|g| g.tag == "FOO" && g.text == "is an example gloss of type FOO"}.size.should == 1
  end
  
  it "correctly identifies multiple-line glosses" do
    @glosses.select {|g| g.tag == "BAR" && g.text == "is a gloss that spans several lines because each line has the same indent or at least that much"}.size.should == 1
  end
  
  it "correctly identifies glosses with nothing on the first line" do
    found = @glosses.select {|g| g.tag == "BLAH" && g.text == "This is a gloss with nothing on the first line."}
    found.size.should == 1
  end
  
  it "correctly identifies glosses with nothing on the first or second lines" do
    found = @glosses.select {|g| g.tag == "cruft" && g.text == "This is a gloss in paragraph format. This is a good format for longer comments."}
    found.size.should == 1
  end
  
  it "correctly identifies glosses with alternate delimiter characters" do
    @glosses.select {|g| g.tag == "ARGH" && g.text == "argh is a gloss with a different delimiter character."}.size.should == 1
  end
  
  it "finds multiple glosses in a message" do
    @glosses.size.should == 5
  end
  
  it "does not create spurious glosses" do
     @glosses.select {|g| g.text =~ /does not contain a gloss|does this one/}.size.should == 0
  end
end
