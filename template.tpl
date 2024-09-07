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
  "displayName": "Firestore Salt Cache",
  "categories": [
    "UTILITY"
  ],
  "description": "Manage a random salt cache with variable lifespan using Firestore. Creates and updates salt value automatically. Uses Template Data Storage to reduce Firestore requests",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "fsPath",
    "displayName": "Salt Cache Firestore Document",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "Path and document name for salt cache",
    "alwaysInSummary": true
  },
  {
    "type": "TEXT",
    "name": "projectId",
    "displayName": "Project ID",
    "simpleValueType": true,
    "help": "add external project id to use Firestore from a different project."
  },
  {
    "type": "TEXT",
    "name": "saltLength",
    "displayName": "Salt String Length",
    "simpleValueType": true,
    "help": "Pick a value between 10 and 64. The result string will have the desired length.",
    "defaultValue": 10,
    "valueValidators": [
      {
        "type": "POSITIVE_NUMBER"
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "expMethod",
    "displayName": "Salt Expiration",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "timer",
        "displayValue": "Define Lifespan"
      },
      {
        "value": "day",
        "displayValue": "Expires At Midnight"
      },
      {
        "value": "never",
        "displayValue": "Never"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "timer",
    "alwaysInSummary": true
  },
  {
    "type": "TEXT",
    "name": "saltLifespan",
    "displayName": "Lifespan in hours",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "POSITIVE_NUMBER"
      }
    ],
    "defaultValue": 24,
    "alwaysInSummary": true,
    "enablingConditions": [
      {
        "paramName": "expMethod",
        "paramValue": "timer",
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "utcOffset",
    "displayName": "UTC Offset (Hours)",
    "simpleValueType": true,
    "defaultValue": 0,
    "valueValidators": [
      {
        "type": "REGEX",
        "args": [
          "^-?(1[0-2]|[0-9])$"
        ]
      }
    ],
    "enablingConditions": [
      {
        "paramName": "expMethod",
        "paramValue": "day",
        "type": "EQUALS"
      }
    ],
    "help": "Enter a number between -12 and +12"
  }
]


___SANDBOXED_JS_FOR_SERVER___

const Firestore = require('Firestore');
const makeNumber = require('makeNumber');
const generateRandom = require('generateRandom');
const getTimestampMillis = require("getTimestampMillis");
const templateDataStorage = require('templateDataStorage');
const Math = require('Math');

const doc = data.fsPath;
let salt, ts = 0;

//create new random value for salt. param: length of new string 
const makeSalt = function(ln) {
  let res = "", 
  allChars = '01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz,;.#+*()/&%$';
  for (var i=0;i<ln-1;i++) {
    res += allChars.charAt(generateRandom(0,allChars.length-1));
   }
   return res;
};

function writeNewSalt(d, p, ts) {
  let s = makeSalt(Math.max(Math.min(data.saltLength||10, 64), 8));
  return Firestore.write(doc, {
    salt: s,
    timestamp: ts || getTimestampMillis() / 1000
  }, {
    projectId: p,
    merge: true,
  }).then(function(result){
    templateDataStorage.setItemCopy('saltcachetimestamp', ts || getTimestampMillis() / 1000);
    templateDataStorage.setItemCopy('saltcachevalue', s);
    return s;
  }, function(){ return undefined;});  
}

//parse timestamp to simple date string - reduced code from https://github.com/addingwell/formatted-date-variable/ 
function parseDate(timestampMillis, offsetHrs) {
  timestampMillis = timestampMillis + (offsetHrs * 1000 * 60 * 60); 
  const timestampDays = Math.floor(timestampMillis / 60 / 60 / 24 / 1000);
  const days = timestampDays + 719468;
  const era = Math.floor((days >= 0 ? days : days - 146096) / 146097);
  const doe = days - era * 146097;
  const yoe = Math.floor((doe + (-Math.floor(doe / 1460)) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const y = yoe + era * 400;
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const d = 1 + doy - Math.floor(((153 * mp) + 2) / 5);
  const m = mp < 10 ? mp + 3 : mp - 9;
  return y + (m <= 2) + "-" + m + "-" + d;
}


function saltStillValid(nw, ts) {
  if (data.expMethod === "day") { 
    var offset = makeNumber(data.utcOffset||0);
    var nw_date = parseDate(nw * 1000, offset);
    var cache_date = parseDate(ts * 1000, offset);
    return (nw_date === cache_date);
  }
  if (data.expMethod === "never") return true; 
  return (data.saltLifespan === 0) || (nw - ts < data.saltLifespan * 60 * 60);
}


/**************************************************************************/

const nw = getTimestampMillis() / 1000;
var cachedSaltValue = templateDataStorage.getItemCopy('saltcachevalue');
var cachedSaltTimestamp = templateDataStorage.getItemCopy('saltcachetimestamp');

if (cachedSaltValue && cachedSaltTimestamp) {
  if (saltStillValid(nw, cachedSaltTimestamp)) {
    //cache exists and still valid
    return cachedSaltValue;
  }
}

//read salt from Firestore 
return Firestore.read(doc, {
  projectId: data.projectId,
}).then(
  function(result) {
    //get salt and timestamp
    salt = result.data.salt;
    ts = result.data.timestamp;
  },
  function(result) {
    salt = "_CREATE_"; 
  }
).then(function() {
  const nw = getTimestampMillis() / 1000;
  //check timestamp against lifespan and return existing or new salt value   
  if ((salt === "_CREATE_") || (!saltStillValid(nw, ts))) {
    //salt is expired - create new salt and store with timestamp
    return writeNewSalt(doc, data.projectId, nw);
  } else return salt;
});


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_firestore",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedOptions",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "read_write"
                  }
                ]
              }
            ]
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
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 29.3.2022, 16:28:33


