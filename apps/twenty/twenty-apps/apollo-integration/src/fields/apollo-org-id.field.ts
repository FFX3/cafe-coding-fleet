import {
  defineField,
  FieldType,
  STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS,
} from 'twenty-sdk/define';

export default defineField({
  universalIdentifier: 'e37eb171-e573-4647-9de0-c0031ec97770',
  objectUniversalIdentifier:
    STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS.company.universalIdentifier,
  name: 'apolloOrgId',
  type: FieldType.TEXT,
  label: 'Apollo Org ID',
  icon: 'IconId',
  description: 'Apollo organization ID for deduplication',
});
