import { defineApplication } from 'twenty-sdk/define';

import {
  APP_DESCRIPTION,
  APP_DISPLAY_NAME,
  APPLICATION_UNIVERSAL_IDENTIFIER,
} from 'src/constants/universal-identifiers';

export default defineApplication({
  universalIdentifier: APPLICATION_UNIVERSAL_IDENTIFIER,
  displayName: APP_DISPLAY_NAME,
  description: APP_DESCRIPTION,
  applicationVariables: {
    APOLLO_API_KEY: {
      universalIdentifier: 'ecdddf88-021e-406c-9719-dc9dad497f72',
      description: 'API key for Apollo.io',
      isSecret: true,
    },
  },
});
