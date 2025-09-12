/// <reference path="./server-gtm-sandboxed-apis.d.ts" />

const sendHttpRequest = require('sendHttpRequest');
const encodeUriComponent = require('encodeUriComponent');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const getRequestHeader = require('getRequestHeader');
const getContainerVersion = require('getContainerVersion');
const generateRandom = require('generateRandom');
const getTimestampMillis = require('getTimestampMillis');
const makeString = require('makeString');
const BigQuery = require('BigQuery');

/*==============================================================================
==============================================================================*/

const traceId = getRequestHeader('trace-id');

const identifiersValues = getIdentifiersValues(data.identifiers);
if (identifiersValues.length === 0) {
  return {};
}

const storeUrl = getStoreUrl();
const postBody = {
  data: [['identifiersValues', 'array-contains-any', identifiersValues]],
  limit: 1
};

log({
  Name: 'StapeStoreReStore',
  Type: 'Request',
  TraceId: traceId,
  EventName: 'StapeStoreReStoreGet',
  RequestMethod: 'POST',
  RequestUrl: storeUrl,
  RequestBody: postBody
});

return sendHttpRequest(
  storeUrl,
  { method: 'POST', headers: { 'Content-Type': 'application/json' } },
  JSON.stringify(postBody)
).then(
  (documents) => {
    const body = JSON.parse(documents.body);
    const document = body && body.length > 0 ? body[0] : {};

    return restoreData(document);
  },
  () => {
    return restoreData({});
  }
);

/*==============================================================================
  Vendor related functions
==============================================================================*/

function restoreData(document) {
  const documentKey = document.key || generateDocumentKey();
  const storedData = document.data || {};
  const dataToStore = {};

  log({
    Name: 'StapeStoreReStore',
    Type: 'Response',
    TraceId: traceId,
    EventName: 'StapeStoreReStoreGet',
    ResponseStatusCode: 200,
    ResponseHeaders: {},
    ResponseBody: storedData
  });

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

  const writeUrl = getWriteUrl(documentKey);
  const mergedIdentifiers = mergeIdentifiers(storedData.identifiers, data.identifiers);
  const objectToStore = {
    identifiers: mergedIdentifiers,
    identifiersValues: getIdentifiersValues(mergedIdentifiers),
    data: dataToStore
  };

  log({
    Name: 'StapeStoreReStore',
    Type: 'Request',
    TraceId: traceId,
    EventName: 'StapeStoreReStorePost',
    RequestMethod: 'POST',
    RequestUrl: writeUrl,
    RequestBody: objectToStore
  });

  return sendHttpRequest(
    writeUrl,
    { method: 'PUT', headers: { 'Content-Type': 'application/json' } },
    JSON.stringify(objectToStore)
  ).then(
    () => {
      log({
        Name: 'StapeStoreReStore',
        Type: 'Response',
        TraceId: traceId,
        EventName: 'StapeStoreReStorePost',
        ResponseStatusCode: 200,
        ResponseHeaders: {},
        ResponseBody: {}
      });

      return dataToStore;
    },
    () => {
      log({
        Name: 'StapeStoreReStore',
        Type: 'Response',
        TraceId: traceId,
        EventName: 'StapeStoreReStorePost',
        ResponseStatusCode: 500,
        ResponseHeaders: {},
        ResponseBody: {}
      });

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

/*==============================================================================
  Helpers
==============================================================================*/

function enc(data) {
  return encodeUriComponent(makeString(data || ''));
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

function log(rawDataToLog) {
  const logDestinationsHandlers = {};
  if (determinateIsLoggingEnabled()) logDestinationsHandlers.console = logConsole;
  if (determinateIsLoggingEnabledForBigQuery()) logDestinationsHandlers.bigQuery = logToBigQuery;

  const keyMappings = {
    // No transformation for Console is needed.
    bigQuery: {
      Name: 'tag_name',
      Type: 'type',
      TraceId: 'trace_id',
      EventName: 'event_name',
      RequestMethod: 'request_method',
      RequestUrl: 'request_url',
      RequestBody: 'request_body',
      ResponseStatusCode: 'response_status_code',
      ResponseHeaders: 'response_headers',
      ResponseBody: 'response_body'
    }
  };

  for (const logDestination in logDestinationsHandlers) {
    const handler = logDestinationsHandlers[logDestination];
    if (!handler) continue;

    const mapping = keyMappings[logDestination];
    const dataToLog = mapping ? {} : rawDataToLog;

    if (mapping) {
      for (const key in rawDataToLog) {
        const mappedKey = mapping[key] || key;
        dataToLog[mappedKey] = rawDataToLog[key];
      }
    }

    handler(dataToLog);
  }
}

function logConsole(dataToLog) {
  logToConsole(JSON.stringify(dataToLog));
}

function logToBigQuery(dataToLog) {
  const connectionInfo = {
    projectId: data.logBigQueryProjectId,
    datasetId: data.logBigQueryDatasetId,
    tableId: data.logBigQueryTableId
  };

  dataToLog.timestamp = getTimestampMillis();

  ['request_body', 'response_headers', 'response_body'].forEach((p) => {
    dataToLog[p] = JSON.stringify(dataToLog[p]);
  });

  BigQuery.insert(connectionInfo, [dataToLog], { ignoreUnknownValues: true });
}

function determinateIsLoggingEnabled() {
  const containerVersion = getContainerVersion();
  const isDebug = !!(
    containerVersion &&
    (containerVersion.debugMode || containerVersion.previewMode)
  );

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

function determinateIsLoggingEnabledForBigQuery() {
  if (data.bigQueryLogType === 'no') return false;
  return data.bigQueryLogType === 'always';
}
