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
