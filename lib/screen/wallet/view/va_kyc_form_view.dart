import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';

import '../controllers/va_kyc_form_controller.dart';

class VAKycFormView extends GetView<VAKycFormController> {
  const VAKycFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Virtual Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: osvanGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('First Name', controller.firstName,
                validator: controller.vReq),
            _field('Last Name', controller.lastName,
                validator: controller.vReq),
            _field('Email', controller.customerEmail,
                keyboard: TextInputType.emailAddress,
                validator: controller.vEmail),
            _field('Phone Number', controller.phoneNumber,
                keyboard: TextInputType.phone, validator: controller.vPhone),
            _field('BVN (11 digits)', controller.bvn,
                keyboard: TextInputType.number, validator: controller.vBvn),

            // Bank selection (safehaven/providus)
            Obx(() => DropdownButtonFormField<String>(
                  value: controller.bank.value,
                  decoration: const InputDecoration(
                    labelText: 'Bank',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'providus', child: Text('Providus')),
                    DropdownMenuItem(
                        value: 'safehaven', child: Text('Safehaven')),
                  ],
                  onChanged: (v) {
                    if (v != null) controller.bank.value = v;
                  },
                )),

            const SizedBox(height: 12),

            // Date of birth only required when bank = providus
            Obx(() {
              final isProvidus = controller.bank.value == 'providus';
              return GestureDetector(
                onTap: () => controller.pickDob(context),
                child: AbsorbPointer(
                  absorbing: true,
                  child: _field(
                    'Date of Birth (YYYY-MM-DD) ${isProvidus ? "*" : "(only for Providus)"}',
                    controller.dateOfBirth,
                    validator: controller.vDobIfProvidus,
                  ),
                ),
              );
            }),

            _field('Reference', controller.reference,
                helper: 'Autofilled; you can edit if needed'),

            const SizedBox(height: 12),
            Obx(() => controller.errorText.value == null
                ? const SizedBox.shrink()
                : Text(controller.errorText.value!,
                    style: const TextStyle(color: Colors.red))),

            const SizedBox(height: 16),
            Obx(() => ElevatedButton(
                  onPressed:
                      controller.isSubmitting.value ? null : controller.submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: osvanGreen,
                      foregroundColor: Colors.white),
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
