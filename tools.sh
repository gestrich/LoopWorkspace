#!/bin/bash

set -e
set -u

#STEPS
#See https://www.bluelabellabs.com/blog/generate-apple-certificates-provisioning-profiles/

PROVISIONING_PROFILE_NAME="Apple Development" #How does this work when you have multiple extensions that use different provisioning profiles?
CODE_SIGNING_IDENTITY="Apple Development"
#CODE_SIGNING_STYLE="Manual" #I suspect this may break it since the PROVISIONING_PROFILE_NAME seems wrong and I'd also need to specify more?
CODE_SIGNING_STYLE="Automatic"

RESULT_PATH="/Users/bill/dev/personal/loop/archives"
ARCHIVE_PATH="$RESULT_PATH/build.xcarchive"
DERIVED_DATA_PATH="$RESULT_PATH/derived_data"
RESULT_BUNDLE_PATH="$RESULT_PATH/resultbundle.xcresult"
EXPORT_PATH="$RESULT_PATH/adhocexport"
EXPORT_OPTIONS_PATH="$RESULT_PATH/exportOptions.plist"
EXPORT_METHOD="ad-hoc"
UPLOAD_SYMBOLS=false

function archive(){
  rm -rf "$RESULT_PATH" 
  mkdir "$RESULT_PATH"
  xcodebuild archive \
    -workspace ${WORKSPACE_NAME}.xcworkspace \
    -scheme ${SCHEME_NAME} \
    -destination generic/platform=iOS \
    -archivePath $ARCHIVE_PATH \
    -derivedDataPath $DERIVED_DATA_PATH \
    -resultBundleVersion 3 \
    -resultBundlePath $RESULT_BUNDLE_PATH \
    -IDEPostProgressNotifications=YES \
    CODE_SIGN_IDENTITY="$CODE_SIGNING_IDENTITY" \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_STYLE=$CODE_SIGNING_STYLE \
    DEVELOPMENT_TEAM=$TEAM_ID \
    COMPILER_INDEX_STORE_ENABLE=NO \
    -hideShellScriptEnvironment \
    -configuration Release
}

function exportAll(){
  # Create exportOptions.plist
cat > ~/Downloads/exportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>compileBitcode</key>
        <false/>
        <key>teamID</key>
        <string>${TEAM_ID}</string>
        <key>method</key>
        <string>${EXPORT_METHOD}</string>
        <key>uploadSymbols</key>
        <${UPLOAD_SYMBOLS}/>
        <key>provisioningProfiles</key>
        <dict>
          <key>${BUNDLE_ID}</key>
          <string>${PROVISIONING_PROFILE_NAME}</string>
        </dict>
</dict>
</plist>
EOF
  xcodebuild -exportArchive \
    -archivePath $ARCHIVE_PATH \
    -exportPath $EXPORT_PATH \
    -exportOptionsPlist ~/Downloads/exportOptions.plist \
    -allowProvisioningUpdates
    #-DVTProvisioningIsManaged=YES \
    #-IDEDistributionLogDirectory=/Volumes/Task/logs/ad-hoc-export-archive-logs \
    #-DVTSkipCertificateValidityCheck=YES \
    #-DVTServicesLogLevel=3 2>&1
    #'-DVTPortalRequest.Endpoint=http://172.16.59.6:8089' \ 

}

function appCenterUploads {
  ../app-center-upload.sh uploadIPA $EXPORT_PATH/Loop.ipa
  ../app-center-upload.sh uploadSymbols $ARCHIVE_PATH/dSYMs
}

function runAll(){
  archive
  exportAll
  appCenterUploads
}


#FAILS!
#xcodebuild archive -workspace Loop.xcworkspace \
#  -scheme "Loop (Workspace)" \
#  -sdk iphoneos \
#  -archivePath ~/Downloads/archive  \
#  -configuration Release

# Check if the function exists
  if [ $# -gt 0 ]; then 
#if declare -f "$1" > /dev/null
  # call arguments verbatim
  "$@"
else
  # Show a helpful error
  echo "Functions Available:"
  typeset -f | awk '!/^main[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
  exit 1
fi
