# Homebrew Formula for Conduit
# To install: brew install --HEAD conduit.rb

class Conduit < Formula
  desc "Cross-platform speech-to-text transcription tool using Groq API"
  homepage "https://github.com/yourusername/conduit"
  url "https://github.com/yourusername/conduit/archive/v1.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/yourusername/conduit.git", branch: "main"

  depends_on "curl"
  depends_on "jq"
  depends_on "sox" => :recommended

  def install
    # Install scripts
    bin.install "transcribe-cross-platform.sh" => "conduit"
    bin.install "install-cross-platform.sh" => "conduit-install"
    
    # Install configuration files
    (etc/"conduit").install ".env.example"
    (etc/"conduit").install ".conduit.yml"
    
    # Install documentation
    doc.install "README.md"
    doc.install "LICENSE"
    doc.install "CHANGELOG.md"
  end

  def post_install
    (etc/"conduit").mkpath
    
    unless (etc/"conduit"/".env").exist?
      (etc/"conduit"/".env").write <<~EOS
        # Groq API Configuration
        GROQ_API_KEY=your_api_key_here
      EOS
      (etc/"conduit"/".env").chmod(0600)
    end
  end

  def caveats
    <<~EOS
      To complete setup:
      1. Add your Groq API key to #{etc}/conduit/.env
      2. Get your API key from: https://console.groq.com/
      
      To use Conduit:
        conduit
      
      For better audio quality, install sox:
        brew install sox
    EOS
  end

  test do
    assert_match "Detected platform", shell_output("#{bin}/conduit --version 2>&1", 1)
  end
end