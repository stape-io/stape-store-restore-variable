___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Stape Data Store reStore",
  "categories": [
    "UTILITY",
    "DATA_WAREHOUSING"
  ],
  "description": "Store data in Stape Data Store by identifiers (user_id, client_id, etc.). Restore data values in case they are found by identifiers. Useful for cookieless, cross-device, and cross-site tracking.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "CHECKBOX",
    "name": "onlyRestore",
    "checkboxText": "Only restore data",
    "simpleValueType": true,
    "help": "It will prevent writing data to the Stape Data Store. Useful if you want to only get data by identifiers."
  },
  {
    "type": "GROUP",
    "name": "identifiersGroup",
    "displayName": "List of identifiers",
    "groupStyle": "ZIPPY_OPEN",
    "subParams": [
      {
        "type": "SIMPLE_TABLE",
        "name": "identifiers",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "Name",
            "name": "name",
            "type": "TEXT",
            "isUnique": true,
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          },
          {
            "defaultValue": "",
            "displayName": "Value",
            "name": "value",
            "type": "TEXT",
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          }
        ],
        "alwaysInSummary": true
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "dataGroup",
    "displayName": "List of data that needs to be restored",
    "groupStyle": "ZIPPY_OPEN",
    "subParams": [
      {
        "type": "SIMPLE_TABLE",
        "name": "dataValues",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "Name",
            "name": "name",
            "type": "TEXT",
            "isUnique": true,
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          },
          {
            "defaultValue": "",
            "displayName": "Value",
            "name": "value",
            "type": "TEXT",
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ],
            "valueHint": "",
            "selectItems": [
              {
                "value": 1,
                "displayValue": "1"
              },
              {
                "value": 2,
                "displayValue": "2"
              }
            ]
          }
        ],
        "alwaysInSummary": true
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "stapeStoreSettingsGroup",
    "displayName": "Stape Data Store Settings",
    "groupStyle": "ZIPPY_OPEN_ON_PARAM",
    "subParams": [
      {
        "type": "TEXT",
        "name": "stapeStoreCollectionName",
        "displayName": "Stape Data Store Collection Name",
        "simpleValueType": true,
        "help": "The name of the collection on the Stape Data Store that contains (or will contain) the document with the data.\n\u003cbr/\u003e\u003cbr/\u003e\nIf not set, the \u003ci\u003edefault\u003c/i\u003e Collection Name will be used.",
        "defaultValue": "default"
      },
      {
        "type": "SELECT",
        "name": "useDifferentStapeStore",
        "displayName": "Use the Stape Data Store database of a different container",
        "macrosInSelect": true,
        "selectItems": [
          {
            "value": true,
            "displayValue": "true"
          },
          {
            "value": false,
            "displayValue": "false"
          }
        ],
        "simpleValueType": true,
        "subParams": [
          {
            "type": "TEXT",
            "name": "stapeStoreContainerApiKey",
            "displayName": "Stape Data Store Container API Key",
            "simpleValueType": true,
            "valueHint": "euk:kzlfoobar:55ec021d429be49e64e691429cf0f27440a1b789kzlfoobar",
            "help": "If you want to interact with the Stape Data Store of a different container hosted on Stape, specify the \u003cb\u003eContainer API Key\u003c/b\u003e of this container.\n\u003cbr/\u003e\u003cbr/\u003e\nTo find the \u003cb\u003eContainer API Key\u003c/b\u003e, go to the \u003ca href\u003d\"https://app.eu.stape.dev/container\"\u003eStape Admin panel\u003c/a\u003e, select the sGTM container which the Stape Data Store you want to interact with, go to the \u003ci\u003eSettings\u003c/i\u003e tab and scroll down to the \u003ci\u003eContainer settings\u003c/i\u003e section.",
            "enablingConditions": [
              {
                "paramName": "useDifferentStapeStore",
                "paramValue": false,
                "type": "NOT_EQUALS"
              }
            ],
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          }
        ],
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const encodeUriComponent = require('encodeUriComponent');
const generateRandom = require('generateRandom');
const getRequestHeader = require('getRequestHeader');
const getTimestampMillis = require('getTimestampMillis');
const getType = require('getType');
const JSON = require('JSON');
const makeString = require('makeString');
const sendHttpRequest = require('sendHttpRequest');

/*==============================================================================
==============================================================================*/

const identifiersValues = getIdentifiersValues(data.identifiers);
if (identifiersValues.length === 0) {
  return {};
}

const storeUrl = getStapeStoreBaseUrl(data);
const postBody = {
  filter: {
    operator: 'and',
    conditions: [
      {
        field: 'identifiersValues',
        operator: 'array-contains-any',
        value: identifiersValues
      }
    ]
  },
  pagination: {
    limit: 1
  }
};

return sendHttpRequest(
  storeUrl,
  { method: 'POST', headers: { 'Content-Type': 'application/json' } },
  JSON.stringify(postBody)
).then(
  (response) => {
    const body = JSON.parse(response.body || '{}');
    const document =
      getType(body) === 'object' &&
      getType(body.data) === 'object' &&
      getType(body.data.items) === 'array' &&
      getType(body.data.items[0]) === 'object'
        ? body.data.items[0]
        : {};

    return restoreData(document);
  },
  (response) => {
    return restoreData({});
  }
);

/*==============================================================================
  Vendor related functions
==============================================================================*/

function restoreData(document) {
  const storedData = document.data || {};
  const dataToStore = {};

  if (data.dataValues && data.dataValues.length > 0) {
    data.dataValues.forEach(function (dataObject) {
      const item = dataObject.value;

      if (item && item.length > 0) {
        dataToStore[dataObject.name] = item;
      } else if (storedData.data && storedData.data[dataObject.name]) {
        dataToStore[dataObject.name] = storedData.data[dataObject.name];
      }
    });
  }

  if (getObjectLength(dataToStore) === 0 || data.onlyRestore) {
    return dataToStore;
  }

  const documentKey = document.key || generateDocumentKey();
  const documentUrl = getStapeStoreDocumentUrl(data, documentKey);
  const mergedIdentifiers = mergeIdentifiers(storedData.identifiers, data.identifiers);
  const objectToStore = {
    identifiers: mergedIdentifiers,
    identifiersValues: getIdentifiersValues(mergedIdentifiers),
    data: dataToStore
  };

  return sendHttpRequest(
    documentUrl,
    { method: 'PUT', headers: { 'Content-Type': 'application/json' } },
    JSON.stringify(objectToStore)
  ).then(
    (response) => {
      return dataToStore;
    },
    (response) => {
      return dataToStore;
    }
  );
}

function getIdentifiersValues(identifiers) {
  const identifiersValues = [];

  if (identifiers && identifiers.length > 0) {
    identifiers.forEach(function (identifier) {
      if (identifier.value) {
        identifiersValues.push(identifier.value);
      }
    });
  }

  return identifiersValues;
}

function mergeIdentifiers(oldIdentifiers, newIdentifiers) {
  let identifiers = [];

  if (oldIdentifiers && oldIdentifiers.length > 0) {
    identifiers = oldIdentifiers;
  }

  if (newIdentifiers && newIdentifiers.length > 0) {
    newIdentifiers.forEach(function (newIdentifier) {
      let identifierFound = false;

      identifiers.forEach(function (identifier) {
        if (identifier.name === newIdentifier.name && newIdentifier.value) {
          identifier.value = newIdentifier.value;
          identifierFound = true;
        }
      });

      if (!identifierFound && newIdentifier.value) {
        identifiers.push(newIdentifier);
      }
    });
  }

  return identifiers;
}

function getStapeStoreBaseUrl(data) {
  let containerIdentifier;
  let defaultDomain;
  let containerApiKey;
  const collectionPath =
    'collections/' + enc(data.stapeStoreCollectionName || 'default') + '/documents';

  const shouldUseDifferentStore =
    isUIFieldTrue(data.useDifferentStapeStore) &&
    getType(data.stapeStoreContainerApiKey) === 'string';
  if (shouldUseDifferentStore) {
    const containerApiKeyParts = data.stapeStoreContainerApiKey.split(':');

    const containerLocation = containerApiKeyParts[0];
    const containerRegion = containerApiKeyParts[3] || 'io';
    containerIdentifier = containerApiKeyParts[1];
    defaultDomain = containerLocation + '.stape.' + containerRegion;
    containerApiKey = containerApiKeyParts[2];
  } else {
    containerIdentifier = getRequestHeader('x-gtm-identifier');
    defaultDomain = getRequestHeader('x-gtm-default-domain');
    containerApiKey = getRequestHeader('x-gtm-api-key');
  }

  return (
    'https://' +
    enc(containerIdentifier) +
    '.' +
    enc(defaultDomain) +
    '/stape-api/' +
    enc(containerApiKey) +
    '/v2/store/' +
    collectionPath
  );
}

function getStapeStoreDocumentUrl(data, documentKey) {
  const storeBaseUrl = getStapeStoreBaseUrl(data);
  return storeBaseUrl + '/' + enc(documentKey);
}

function generateDocumentKey() {
  const rnd = makeString(generateRandom(1000000000, 2147483647));

  return 'restor_' + makeString(getTimestampMillis()) + rnd;
}

/*==============================================================================
  Helpers
==============================================================================*/

function isUIFieldTrue(field) {
  return [true, 'true', 1, '1'].indexOf(field) !== -1;
}

function enc(data) {
  if (['null', 'undefined'].indexOf(getType(data)) !== -1) data = '';
  return encodeUriComponent(makeString(data));
}

function getObjectLength(object) {
  let length = 0;

  for (let key in object) {
    if (object.hasOwnProperty(key)) {
      ++length;
    }
  }
  return length;
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "headerWhitelist",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "x-gtm-identifier"
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "x-gtm-default-domain"
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "x-gtm-api-key"
                  }
                ]
              }
            ]
          }
        },
        {
          "key": "headersAllowed",
          "value": {
            "type": 8,
            "boolean": true
          }
        },
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

2026-10-19 - Change Notes:
  - Stape Store was renamed to Stape Data Store.

2026-05-21 Change Notes:
 - Console and BigQuery logging removal.

Created on 15/01/2024, 17:29:11

