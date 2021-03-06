require 'spec_helper'

describe EY::Repo do
  let(:path) { p = TMPDIR.join('ey-test'); p.mkpath; p }

  before(:each) do
    Dir.chdir(path) { `git init -q` }
    ENV['GIT_DIR'] = path.join('.git').to_s
  end

  after(:each) do
    path.rmtree
    ENV.delete('GIT_DIR')
  end

  def set_head(head)
    path.join('.git','HEAD').open('w') {|f| f.write(head) }
  end

  def set_url(url, remote)
    `git remote add #{remote} #{url}`
  end

  describe ".new" do
    it "creates a working repo object in a repo" do
      expect(EY::Repo.new.remotes).to be_empty
    end

    it "doesn't raise if created outside a repository until trying to do something" do
      ENV['GIT_DIR'] = nil
      Dir.chdir('/tmp') do
        repo = EY::Repo.new
        expect { repo.remotes }.to raise_error(EY::Repo::NotAGitRepository)
      end
    end
  end

  describe ".exist?" do
    it "is true when env vars are set to a repo" do
      expect(EY::Repo).to be_exist
    end

    it "is true when pwd is a repo" do
      Dir.chdir(File.dirname(ENV['GIT_DIR'])) do
        ENV['GIT_DIR'] = nil
        expect(EY::Repo).to be_exist
      end
    end

    it "is false when outside of any repo" do
      ENV['GIT_DIR'] = nil
      Dir.chdir('/tmp') do
        expect(EY::Repo).not_to be_exist
      end
    end
  end

  context "in a repository dir" do

    before(:each) do
      @repo = EY::Repo.new
    end

    describe "current_branch method" do
      it "returns the name of the current branch" do
        set_head "ref: refs/heads/master"
        expect(@repo.current_branch).to eq("master")
      end

      it "returns nil if there is no current branch" do
        set_head "20bf478ab6a91ec5771130aa4c8cfd3d150c4146"
        expect(@repo.current_branch).to be_nil
      end
    end # current_branch

    describe "#fail_on_no_remotes!" do
      it "raises when there are no remotes" do
        expect { @repo.fail_on_no_remotes! }.to raise_error(EY::Repo::NoRemotesError)
      end
    end

  end
end
