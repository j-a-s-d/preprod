# preprod by Javier Santo Domingo (j-a-s-d@coderesearchlabs.com)

import xam

reexport(preprod / exports, exports)

let PREPROD_VERSION*: SemanticVersion = newSemanticVersion(1, 1, 1)
