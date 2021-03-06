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

===YUCK=== this is a gloss that has two ===MALFORMED=== glosses attached ===TO=== it

===BLEAH=== this is a gloss that has two ===MALFORMED=== glosses attached 
   ===ONE=== of which is on the second line

Foo

  ===INDENTED=== this should only be a gloss if indenting is allowed
  ===INDENTED2=== this should not be part of the preceding gloss
    but these lines should be appended on

abcCRUFTabc this should not be a gloss
END
  
  SECOND_TEST = <<-END
This is a test commit.
  ===FOO=== this is a bogus gloss

===BAR=== this is not a bogus gloss, but ===MIDLINE=== this is
  ===MIDLINE2=== and so is this


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

  it "correctly splits malformed glosses with more than one midline gloss when asked to" do
    yuck = @glosses.select {|g| g.tag == "YUCK"}
    yuck.size.should == 1
    splits = Gliss::split_glosses(yuck[0], true)
    splits.size.should == 3
    splits.map{|g| g.tag}.should == %w{YUCK MALFORMED TO}
    splits.map{|g| g.text}.should == ["this is a gloss that has two", "glosses attached", "it"]
  end

  it "correctly splits malformed glosses with more than one mid-multiline gloss gloss when asked to" do
    bleah = @glosses.select {|g| g.tag == "BLEAH"}
    bleah.size.should == 1
    splits = Gliss::split_glosses(bleah[0], true)
    splits.size.should == 3
    splits.map{|g| g.tag}.should == %w{BLEAH MALFORMED ONE}
    splits.map{|g| g.text}.should == ["this is a gloss that has two", "glosses attached", "of which is on the second line"]
  end

  it "correctly operates in permissive mode" do
    @glosses = Gliss.glosses_in(SECOND_TEST, nil, true)
    @glosses.size.should == 2
    bar = @glosses.select {|g| g.tag == "BAR"}
    bar.size.should == 1
    splits = Gliss::split_glosses(bar[0], true)
    splits.size.should == 3
    splits.map{|g| g.tag}.should == %w{BAR MIDLINE MIDLINE2}
    splits.map{|g| g.text}.should == ["this is not a bogus gloss, but", "this is", "and so is this"]
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
    @glosses.size.should == 8
  end
  
  it "does not create spurious glosses" do
     @glosses.select {|g| g.text =~ /does not contain a gloss|does this one/}.size.should == 0
  end
end
