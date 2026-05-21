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
