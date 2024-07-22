describe Fastlane::Actions::GhaSecretsCheckAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The gha_secrets_check plugin is working!")

      Fastlane::Actions::GhaSecretsCheckAction.run(nil)
    end
  end
end
