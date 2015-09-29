require "spec_helper"

describe ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow do
  include WorkflowSpecHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:ems)      { FactoryGirl.create(:ems_microsoft) }
  let(:template) { FactoryGirl.create(:template_microsoft, :name => "template", :ext_management_system => ems) }

  before do
    described_class.any_instance.stub(:update_field_visibility)
  end

  it "pass platform attributes to automate" do
    stub_dialog
    assert_automate_dialog_lookup('infra', 'microsoft')

    described_class.new({}, admin.userid)
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Provision requested by [#{admin.userid}] for VM:#{template.id}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values.merge!(:src_vm_id => template.id, :vm_tags => [])

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_migrate_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provision request was successfully updated by [#{alt_user.userid}] for VM:#{template.id}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end
  end
end