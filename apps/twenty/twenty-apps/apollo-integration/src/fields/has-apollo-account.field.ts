import {
  defineField,
  FieldType,
  STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS,
} from 'twenty-sdk/define';

export default defineField({
  universalIdentifier: 'bb4f785a-4e0e-4dcd-bf5d-d754a52b9ae4',
  objectUniversalIdentifier:
    STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS.company.universalIdentifier,
  name: 'hasApolloAccount',
  type: FieldType.BOOLEAN,
  label: 'Has Apollo Account',
  icon: 'IconCheck',
  description: 'Whether this company has been added as an account in Apollo',
  defaultValue: false,
});
