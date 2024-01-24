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
  "displayName": "Stape Store reStore",
  "description": "Store data inside the Stape Store by identifiers (user_id, client_id, etc.). Restore data values in case they are found by identifiers. Useful for cookieless, cross-device, and cross-site tracking.",
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
    "help": "It will prevent writing data to the Stape Store. Useful if you want to only get data by identifiers."
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
    "displayName": "Logs Settings",
    "name": "logsGroup",
    "groupStyle": "ZIPPY_CLOSED",
    "type": "GROUP",
    "subParams": [
      {
        "type": "RADIO",
        "name": "logType",
        "radioItems": [
          {
            "value": "no",
            "displayValue": "Do not log"
          },
          {
            "value": "debug",
            "displayValue": "Log to console during debug and preview"
          },
          {
            "value": "always",
            "displayValue": "Always log to console"
          }
        ],
        "simpleValueType": true,
        "defaultValue": "debug"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const sendHttpRequest = require('sendHttpRequest');
const encodeUriComponent = require('encodeUriComponent');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const getRequestHeader = require('getRequestHeader');
const getContainerVersion = require('getContainerVersion');
const generateRandom = require('generateRandom');
const getTimestampMillis = require('getTimestampMillis');
const makeString = require('makeString');

const isLoggingEnabled = determinateIsLoggingEnabled();
const traceId = isLoggingEnabled ? getRequestHeader('trace-id') : undefined;

const identifiersValues = getIdentifiersValues(data.identifiers);
if (identifiersValues.length === 0) {
    return {};
}

let storeUrl = getStoreUrl();
let postBody = {
    data: [[
      'identifiersValues',
      'array-contains-any',
      identifiersValues
    ]],
    limit: 1
};

if (isLoggingEnabled) {
    logToConsole(
      JSON.stringify({
          Name: 'StapeStoreReStore',
          Type: 'Request',
          TraceId: traceId,
          EventName: 'StapeStoreReStoreGet',
          RequestMethod: 'POST',
          RequestUrl: storeUrl,
          RequestBody: postBody,
      })
    );
}

return sendHttpRequest(storeUrl, {method: 'POST', headers: { 'Content-Type': 'application/json' }}, JSON.stringify(postBody))
  .then((documents) => {
      let body = JSON.parse(documents.body);
      let document = body && body.length > 0 ? body[0] : {};

      return restoreData(document);
  }, () => {
      return restoreData({});
  });

function restoreData(document) {
    let documentKey = document.key || generateDocumentKey();
    let storedData = document.data || {};
    let dataToStore = {};


    if (isLoggingEnabled) {
        logToConsole(
          JSON.stringify({
              Name: 'StapeStoreReStore',
              Type: 'Response',
              TraceId: traceId,
              EventName: 'StapeStoreReStoreGet',
              ResponseStatusCode: 200,
              ResponseHeaders: {},
              ResponseBody: storedData,
          })
        );
    }

    if (data.dataValues && data.dataValues.length > 0) {
        data.dataValues.forEach(function (dataObject) {
            let item = dataObject.value;

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

    let writeUrl = getWriteUrl(documentKey);
    let mergedIdentifiers = mergeIdentifiers(storedData.identifiers, data.identifiers);
    let objectToStore = {
        identifiers: mergedIdentifiers,
        identifiersValues: getIdentifiersValues(mergedIdentifiers),
        data: dataToStore,
    };

    if (isLoggingEnabled) {
        logToConsole(
          JSON.stringify({
              Name: 'StapeStoreReStore',
              Type: 'Request',
              TraceId: traceId,
              EventName: 'StapeStoreReStorePost',
              RequestMethod: 'POST',
              RequestUrl: writeUrl,
              RequestBody: objectToStore,
          })
        );
    }

    return sendHttpRequest(writeUrl, {method: 'PUT', headers: { 'Content-Type': 'application/json' }}, JSON.stringify(objectToStore))
      .then(() => {
          if (isLoggingEnabled) {
              logToConsole(
                JSON.stringify({
                    Name: 'StapeStoreReStore',
                    Type: 'Response',
                    TraceId: traceId,
                    EventName: 'StapeStoreReStorePost',
                    ResponseStatusCode: 200,
                    ResponseHeaders: {},
                    ResponseBody: {},
                })
              );
          }

          return dataToStore;
      }, function () {
          if (isLoggingEnabled) {
              logToConsole(
                JSON.stringify({
                    Name: 'StapeStoreReStore',
                    Type: 'Response',
                    TraceId: traceId,
                    EventName: 'StapeStoreReStorePost',
                    ResponseStatusCode: 500,
                    ResponseHeaders: {},
                    ResponseBody: {},
                })
              );
          }

          return dataToStore;
      });
}

function getIdentifiersValues(identifiers) {
    let identifiersValues = [];

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

function getObjectLength(object) {
    let length = 0;

    for (let key in object) {
        if (object.hasOwnProperty(key)) {
            ++length;
        }
    }
    return length;
}

function getStoreUrl() {
  const containerIdentifier = getRequestHeader('x-gtm-identifier');
  const defaultDomain = getRequestHeader('x-gtm-default-domain');
  const containerApiKey = getRequestHeader('x-gtm-api-key');

  return (
    'https://' +
    enc(containerIdentifier) +
    '.' +
    enc(defaultDomain) +
    '/stape-api/' +
    enc(containerApiKey) +
    '/v1/store'
  );
}

function getWriteUrl(documentKey) {
  return storeUrl + '/' + enc(documentKey);
}

function generateDocumentKey() {
  const rnd = makeString(generateRandom(1000000000, 2147483647));

  return 'restor_' + makeString(getTimestampMillis()) + rnd;
}

function determinateIsLoggingEnabled() {
    const containerVersion = getContainerVersion();
    const isDebug = !!(containerVersion && (containerVersion.debugMode || containerVersion.previewMode));

    if (!data.logType) {
        return isDebug;
    }

    if (data.logType === 'no') {
        return false;
    }

    if (data.logType === 'debug') {
        return isDebug;
    }

    return data.logType === 'always';
}

function enc(data) {
  data = data || '';
  return encodeUriComponent(data);
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
                    "string": "trace-id"
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
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
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
        "publicId": "read_container_data",
        "versionId": "1"
      },
      "param": []
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

Created on 15/01/2024, 17:29:11


