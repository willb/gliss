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
===UGH=== this is a gloss that has a ===MALFORMED=== gloss attached

Foo

  ===INDENTED=== this should only be a gloss if indenting is allowed
  ===INDENTED2=== this should not be part of the preceding gloss
    but these lines should be appended on

abcCRUFTabc this should not be a gloss
END
  
  before(:each) do
    @glosses = Gliss.glosses_in(TEST_MESSAGE)
  end
  
  it "correctly splits glosses when asked to" do
    ugh = @glosses.select {|g| g.tag == "UGH"}
    ugh.size.should == 1
    splits = Gliss::split_glosses(ugh[0], true)
    splits.size.should == 2
    splits[0].tag.should == "UGH"
    splits[0].text.should == "this is a gloss that has a"
    splits[1].text.should == "gloss attached"
    splits[1].tag.should == "MALFORMED"
  end
  
  it "correctly identifies single-line glosses" do
    @glosses.select {|g| g.tag == "FOO" && g.text == "is an example gloss of type FOO"}.size.should == 1
  end

  it "does not spuriously identify indented glosses" do
    @glosses.select {|g| g.tag == "INDENTED"}.size.should == 0
    @glosses.select {|g| g.tag == "INDENTED2"}.size.should == 0
  end

  it "correctly identifies indented glosses when told to" do
    @glosses = Gliss.glosses_in(TEST_MESSAGE, nil, true)
    @glosses.select {|g| g.tag == "INDENTED"}.size.should == 1
  end
  
  it "correctly identifies consecutive indented glosses" do
    @glosses = Gliss.glosses_in(TEST_MESSAGE, nil, true)
    @glosses.select {|g| g.tag == "INDENTED"}.size.should == 1
    @glosses.select {|g| g.tag == "INDENTED" && g.text == "this should only be a gloss if indenting is allowed"}.size.should == 1
    @glosses.select {|g| g.tag == "INDENTED" && g.text =~ /INDENTED2/}.size.should == 0
    @glosses.select {|g| g.tag == "INDENTED2"}.size.should == 1
    @glosses.select {|g| g.tag == "INDENTED2" && g.text =~ /not be part of the preceding gloss/}.size.should == 1
  end

  it "correctly identifies indented multiline glosses when told to" do
    @glosses = Gliss.glosses_in(TEST_MESSAGE, nil, true)
    @glosses.select {|g| g.tag == "INDENTED2"}.size.should == 1
    @glosses.select {|g| g.tag == "INDENTED2" && g.text =~ /but these lines should be appended on/}.size.should == 1
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
    @glosses.size.should == 6
  end
  
  it "does not create spurious glosses" do
     @glosses.select {|g| g.text =~ /does not contain a gloss|does this one/}.size.should == 0
  end
end
