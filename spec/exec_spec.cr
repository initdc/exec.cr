require "./spec_helper"

describe Exec do
  it "print lines" do
    Exec.run("sudo apt update")
  end

  it "not print but also get stdout" do
    r = Exec.run("uname", output: File.open(File::NULL, "w"))
    r.success?.should be_true
    r.stdout.should eq "Linux\n"

    r = Exec.run("unamea", output: File.open(File::NULL, "w"))
    r.success?.should be_false
    r.stdout.should eq ""
    r.exit_code.should eq 127
  end

  it "return 0" do
    Exec.code("uname").should eq 0
  end

  it "accept multi string" do
    Exec.code("uname -s").should eq 0
  end

  it "return 127" do
    Exec.code("unamea").should eq 127
  end

  it "get Linux" do
    Exec.output("uname").should eq "Linux"
  end

  it "get Linux\n" do
    Exec.output("uname", false).should eq "Linux\n"
  end

  it "log to file" do
    tempfile = File.tempfile("test_", ".log")
    File.open(tempfile.path, "a+") do |io|
      Exec.run("uname", output: io)
    end

    tempfile.gets_to_end.should eq "Linux\n"
    tempfile.delete
  end

  it "list file" do
    Exec.each_line("ls spec").should eq ["exec_spec.cr\n", "spec_helper.cr\n"]
  end

  it "list file with option" do
    Exec.each_line("ls spec", chomp: true).should eq ["exec_spec.cr", "spec_helper.cr"]
  end
end
