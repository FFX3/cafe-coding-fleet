import {
  defineField,
  FieldType,
  STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS,
} from 'twenty-sdk/define';

export default defineField({
  universalIdentifier: 'c4a7ec98-14ba-49e8-8e52-b379e1ef4a6d',
  objectUniversalIdentifier:
    STANDARD_OBJECT_UNIVERSAL_IDENTIFIERS.company.universalIdentifier,
  name: 'apolloSearchCriteria',
  type: FieldType.RAW_JSON,
  label: 'Apollo Search Criteria',
  icon: 'IconSearch',
  description: 'The Apollo search filters that found this company',
});
