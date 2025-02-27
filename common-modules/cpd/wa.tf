resource "local_file" "wa_cr_yaml" {
  content  = data.template_file.wa_cr.rendered
  filename = "${local.cpd_workspace}/wa_cr.yaml"
}

resource "local_file" "wa_sub_yaml" {
  content  = data.template_file.wa_sub.rendered
  filename = "${local.cpd_workspace}/wa_sub.yaml"
}

resource "local_file" "wa_temp_patch_yaml" {
  content  = data.template_file.wa_temporary_patch.rendered
  filename = "${local.cpd_workspace}/wa_temp_patch.yaml"
}

resource "null_resource" "install_wa" {
  count = var.watson_assistant.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating Watson Assistant Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/wa_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-watson-assistant-operator ${local.operator_namespace}

echo 'Apply the following temporary fix to allow certificates to be enabled for the Certificate management service'
export INSTANCE=${local.wa_instance}
oc create -f ${self.triggers.cpd_workspace}/wa_temp_patch.yaml
sleep 3m

echo 'Create Watson Assistant CR'
oc create -f ${self.triggers.cpd_workspace}/wa_cr.yaml
sleep 30
echo 'check the Watson Assistant cr status'
bash cpd/scripts/check-wa-cr-status.sh WatsonAssistant wa ${var.cpd_namespace} watsonAssistantStatus
EOF
  }
  depends_on = [
    null_resource.install_ebd,
    local_file.wa_cr_yaml,
    local_file.wa_sub_yaml,
    local_file.wa_temp_patch_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
