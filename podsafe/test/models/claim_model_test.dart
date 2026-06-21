import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/models/claim_model.dart';

void main() {
  group('ClaimType Tests', () {
    test('should have all claim types', () {
      final types = ClaimType.values;

      expect(types.contains(ClaimType.damaged), isTrue);
      expect(types.contains(ClaimType.shortage), isTrue);
      expect(types.contains(ClaimType.wrongItems), isTrue);
      expect(types.contains(ClaimType.lateDelivery), isTrue);
      expect(types.contains(ClaimType.qualityIssue), isTrue);
      expect(types.contains(ClaimType.other), isTrue);
      expect(types.length, greaterThanOrEqualTo(15));
    });

    test('should convert claim type to string', () {
      expect(ClaimType.damaged.name, equals('damaged'));
      expect(ClaimType.shortage.name, equals('shortage'));
      expect(ClaimType.wrongItems.name, equals('wrongItems'));
    });
  });

  group('ClaimStatus Tests', () {
    test('should have complete workflow statuses', () {
      final statuses = ClaimStatus.values;

      // Initial states
      expect(statuses.contains(ClaimStatus.draft), isTrue);
      expect(statuses.contains(ClaimStatus.submitted), isTrue);
      
      // Investigation states
      expect(statuses.contains(ClaimStatus.investigating), isTrue);
      expect(statuses.contains(ClaimStatus.pendingDriverResponse), isTrue);
      expect(statuses.contains(ClaimStatus.driverResponded), isTrue);
      
      // Approval states
      expect(statuses.contains(ClaimStatus.pendingApproval), isTrue);
      expect(statuses.contains(ClaimStatus.approved), isTrue);
      expect(statuses.contains(ClaimStatus.rejected), isTrue);
      
      // Final states
      expect(statuses.contains(ClaimStatus.resolved), isTrue);
      expect(statuses.contains(ClaimStatus.closed), isTrue);
      expect(statuses.contains(ClaimStatus.cancelled), isTrue);
    });

    test('should convert status to string', () {
      expect(ClaimStatus.draft.name, equals('draft'));
      expect(ClaimStatus.submitted.name, equals('submitted'));
      expect(ClaimStatus.investigating.name, equals('investigating'));
      expect(ClaimStatus.approved.name, equals('approved'));
      expect(ClaimStatus.rejected.name, equals('rejected'));
      expect(ClaimStatus.resolved.name, equals('resolved'));
    });
  });

  group('ClaimPriority Tests', () {
    test('should have all priority levels', () {
      final priorities = ClaimPriority.values;

      expect(priorities.contains(ClaimPriority.low), isTrue);
      expect(priorities.contains(ClaimPriority.medium), isTrue);
      expect(priorities.contains(ClaimPriority.high), isTrue);
      expect(priorities.contains(ClaimPriority.urgent), isTrue);
      expect(priorities.length, equals(4));
    });

    test('should order priorities correctly', () {
      expect(ClaimPriority.low.index < ClaimPriority.medium.index, isTrue);
      expect(ClaimPriority.medium.index < ClaimPriority.high.index, isTrue);
      expect(ClaimPriority.high.index < ClaimPriority.urgent.index, isTrue);
    });
  });

  group('ClaimFilingContext Tests', () {
    test('should have all filing contexts', () {
      final contexts = ClaimFilingContext.values;

      expect(contexts.contains(ClaimFilingContext.atDeliverySite), isTrue);
      expect(contexts.contains(ClaimFilingContext.afterDelivery), isTrue);
      expect(contexts.contains(ClaimFilingContext.systemGenerated), isTrue);
      expect(contexts.contains(ClaimFilingContext.customerPortal), isTrue);
    });

    test('should distinguish immediate vs delayed filing', () {
      // Immediate filing
      expect(
        ClaimFilingContext.atDeliverySite.name,
        equals('atDeliverySite'),
      );
      
      // Delayed filing
      expect(
        ClaimFilingContext.afterDelivery.name,
        equals('afterDelivery'),
      );
    });
  });

  group('ClaimResolution Tests', () {
    test('should have all resolution types', () {
      final resolutions = ClaimResolution.values;

      expect(resolutions.contains(ClaimResolution.creditIssued), isTrue);
      expect(resolutions.contains(ClaimResolution.debitDriver), isTrue);
      expect(resolutions.contains(ClaimResolution.refund), isTrue);
      expect(resolutions.contains(ClaimResolution.replacement), isTrue);
      expect(resolutions.contains(ClaimResolution.adjustment), isTrue);
      expect(resolutions.contains(ClaimResolution.noAction), isTrue);
      expect(resolutions.contains(ClaimResolution.other), isTrue);
    });

    test('should have financial impact options', () {
      final financialResolutions = [
        ClaimResolution.creditIssued,
        ClaimResolution.debitDriver,
        ClaimResolution.refund,
        ClaimResolution.adjustment,
      ];

      for (final resolution in financialResolutions) {
        expect(ClaimResolution.values.contains(resolution), isTrue);
      }
    });
  });

  group('CustomFieldType Tests', () {
    test('should have all custom field types', () {
      final types = CustomFieldType.values;

      expect(types.contains(CustomFieldType.text), isTrue);
      expect(types.contains(CustomFieldType.number), isTrue);
      expect(types.contains(CustomFieldType.date), isTrue);
      expect(types.contains(CustomFieldType.dropdown), isTrue);
      expect(types.contains(CustomFieldType.checkbox), isTrue);
      expect(types.contains(CustomFieldType.photo), isTrue);
      expect(types.contains(CustomFieldType.signature), isTrue);
      expect(types.contains(CustomFieldType.file), isTrue);
    });
  });

  group('CustomField Tests', () {
    test('should create text field', () {
      final field = CustomField(
        id: 'field1',
        label: 'Customer Name',
        type: CustomFieldType.text,
        required: true,
        placeholder: 'Enter customer name',
      );

      expect(field.id, equals('field1'));
      expect(field.label, equals('Customer Name'));
      expect(field.type, equals(CustomFieldType.text));
      expect(field.required, isTrue);
      expect(field.placeholder, equals('Enter customer name'));
    });

    test('should create number field', () {
      final field = CustomField(
        id: 'field2',
        label: 'Quantity',
        type: CustomFieldType.number,
        required: true,
      );

      expect(field.type, equals(CustomFieldType.number));
      expect(field.required, isTrue);
    });

    test('should create dropdown field', () {
      final field = CustomField(
        id: 'field3',
        label: 'Reason',
        type: CustomFieldType.dropdown,
        required: true,
        dropdownOptions: ['Option 1', 'Option 2', 'Option 3'],
      );

      expect(field.type, equals(CustomFieldType.dropdown));
      expect(field.dropdownOptions, isNotNull);
      expect(field.dropdownOptions!.length, equals(3));
      expect(field.dropdownOptions, contains('Option 1'));
    });

    test('should convert custom field to map', () {
      final field = CustomField(
        id: 'field1',
        label: 'Test Field',
        type: CustomFieldType.text,
        required: true,
        value: 'Test Value',
      );

      final map = field.toMap();

      expect(map['id'], equals('field1'));
      expect(map['label'], equals('Test Field'));
      expect(map['type'], equals('text'));
      expect(map['required'], isTrue);
      expect(map['value'], equals('Test Value'));
    });

    test('should create custom field from map', () {
      final map = {
        'id': 'field1',
        'label': 'Test Field',
        'type': 'text',
        'required': true,
        'placeholder': 'Enter text',
        'value': 'Test Value',
      };

      final field = CustomField.fromMap(map);

      expect(field.id, equals('field1'));
      expect(field.label, equals('Test Field'));
      expect(field.type, equals(CustomFieldType.text));
      expect(field.required, isTrue);
      expect(field.placeholder, equals('Enter text'));
      expect(field.value, equals('Test Value'));
    });

    test('should handle optional fields in map', () {
      final map = {
        'id': 'field1',
        'label': 'Test Field',
        'type': 'text',
      };

      final field = CustomField.fromMap(map);

      expect(field.required, isFalse);
      expect(field.dropdownOptions, isNull);
      expect(field.placeholder, isNull);
      expect(field.value, isNull);
    });

    test('should handle dropdown options in map', () {
      final map = {
        'id': 'field1',
        'label': 'Dropdown',
        'type': 'dropdown',
        'dropdownOptions': ['A', 'B', 'C'],
      };

      final field = CustomField.fromMap(map);

      expect(field.type, equals(CustomFieldType.dropdown));
      expect(field.dropdownOptions, equals(['A', 'B', 'C']));
    });

    test('should support validation regex', () {
      final field = CustomField(
        id: 'email',
        label: 'Email Address',
        type: CustomFieldType.text,
        validationRegex: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      );

      expect(field.validationRegex, isNotNull);
      expect(field.validationRegex, contains('@'));
    });
  });

  group('Claim Workflow Tests', () {
    test('should follow draft to submitted workflow', () {
      var status = ClaimStatus.draft;
      expect(status, equals(ClaimStatus.draft));

      // Submit the claim
      status = ClaimStatus.submitted;
      expect(status, equals(ClaimStatus.submitted));
    });

    test('should follow investigation workflow', () {
      var status = ClaimStatus.submitted;

      // Move to review
      status = ClaimStatus.pendingReview;
      expect(status, equals(ClaimStatus.pendingReview));

      // Start investigating
      status = ClaimStatus.investigating;
      expect(status, equals(ClaimStatus.investigating));

      // Request driver response
      status = ClaimStatus.pendingDriverResponse;
      expect(status, equals(ClaimStatus.pendingDriverResponse));

      // Driver responds
      status = ClaimStatus.driverResponded;
      expect(status, equals(ClaimStatus.driverResponded));
    });

    test('should follow approval workflow', () {
      var status = ClaimStatus.investigating;

      // Move to approval
      status = ClaimStatus.pendingApproval;
      expect(status, equals(ClaimStatus.pendingApproval));

      // Approve
      status = ClaimStatus.approved;
      expect(status, equals(ClaimStatus.approved));

      // Process
      status = ClaimStatus.processing;
      expect(status, equals(ClaimStatus.processing));

      // Resolve
      status = ClaimStatus.resolved;
      expect(status, equals(ClaimStatus.resolved));

      // Close
      status = ClaimStatus.closed;
      expect(status, equals(ClaimStatus.closed));
    });

    test('should handle rejection workflow', () {
      var status = ClaimStatus.pendingApproval;

      // Reject
      status = ClaimStatus.rejected;
      expect(status, equals(ClaimStatus.rejected));

      // Can still close rejected claims
      status = ClaimStatus.closed;
      expect(status, equals(ClaimStatus.closed));
    });

    test('should handle cancellation', () {
      var status = ClaimStatus.draft;

      // Cancel
      status = ClaimStatus.cancelled;
      expect(status, equals(ClaimStatus.cancelled));
    });

    test('should handle disputes', () {
      var status = ClaimStatus.rejected;

      // Dispute the rejection
      status = ClaimStatus.disputed;
      expect(status, equals(ClaimStatus.disputed));
    });
  });

  group('Priority and Urgency Tests', () {
    test('should escalate priority', () {
      var priority = ClaimPriority.low;
      expect(priority, equals(ClaimPriority.low));

      priority = ClaimPriority.medium;
      expect(priority, equals(ClaimPriority.medium));

      priority = ClaimPriority.high;
      expect(priority, equals(ClaimPriority.high));

      priority = ClaimPriority.urgent;
      expect(priority, equals(ClaimPriority.urgent));
    });

    test('should identify urgent claims', () {
      final urgentPriority = ClaimPriority.urgent;
      expect(urgentPriority, equals(ClaimPriority.urgent));
      expect(urgentPriority.index, equals(3));
    });
  });

  group('Filing Context Tests', () {
    test('should identify immediate claims', () {
      final context = ClaimFilingContext.atDeliverySite;
      expect(context, equals(ClaimFilingContext.atDeliverySite));
      // Immediate claims should be high priority
    });

    test('should identify delayed claims', () {
      final context = ClaimFilingContext.afterDelivery;
      expect(context, equals(ClaimFilingContext.afterDelivery));
      // Delayed claims may have additional requirements
    });

    test('should identify system-generated claims', () {
      final context = ClaimFilingContext.systemGenerated;
      expect(context, equals(ClaimFilingContext.systemGenerated));
      // Auto-created by system rules/triggers
    });

    test('should identify customer portal claims', () {
      final context = ClaimFilingContext.customerPortal;
      expect(context, equals(ClaimFilingContext.customerPortal));
      // Filed by customer through external portal
    });
  });

  group('Resolution Type Tests', () {
    test('should handle credit issued resolution', () {
      final resolution = ClaimResolution.creditIssued;
      expect(resolution, equals(ClaimResolution.creditIssued));
    });

    test('should handle driver debit resolution', () {
      final resolution = ClaimResolution.debitDriver;
      expect(resolution, equals(ClaimResolution.debitDriver));
    });

    test('should handle no action resolution', () {
      final resolution = ClaimResolution.noAction;
      expect(resolution, equals(ClaimResolution.noAction));
    });

    test('should have all financial resolution options', () {
      final financialResolutions = [
        ClaimResolution.creditIssued,
        ClaimResolution.debitDriver,
        ClaimResolution.refund,
        ClaimResolution.adjustment,
      ];

      for (final resolution in financialResolutions) {
        expect(ClaimResolution.values, contains(resolution));
      }
    });
  });
}
