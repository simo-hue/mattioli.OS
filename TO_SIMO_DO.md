# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

---

"Validation failed (409)
Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect. (ID: 6fdd8441-3c28-4944-a92f-860e9580ee0f)" and here is the ful verification log: "2026-07-17 00:36:13.031 DEBUG: [ContentDelivery.Uploader.A1E594780] 
--- Transporter ---
ContentDelivery version 26.30.2 (173002) (API 0)
Macintosh; macOS 26.5.1 25F80 (arm64)
Free disk space: 240.062GB
2026-07-17 00:36:13.032 DEBUG: [ContentDelivery.Uploader.A1E594780] Created log file at path '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Logs/ContentDelivery/com.apple.TransporterApp/com.apple.TransporterApp_Upload_2026-07-17_00-36-13_030.txt'.
2026-07-17 00:36:13.033 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Contacting Apple Services…
2026-07-17 00:36:13.035 DEBUG: [ContentDelivery.Uploader.A1E594780] APNS device token specified (bundle ID 'com.apple.TransporterApp').
2026-07-17 00:36:13.035 DEBUG: [ContentDelivery.Uploader.A1E594780] Will request push notifications for upload.
2026-07-17 00:36:13.040 DEBUG: [ContentDelivery.Uploader.A1BD4F840] *** Launching: /usr/bin/log stream --predicate process contains "Transporter" and subsystem == "com.apple.network" --debug --info --style compact
2026-07-17 00:36:13.040 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CREATE BUILD (ASSET_UPLOAD) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds
     timeout: 900 seconds
      method: POST
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Length" = 526;
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:36:13Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABB+4xkKhKIkDdYmyttb1p5AgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: {"data":{"attributes":{"cfBundleShortVersionString":"1.1.2","cfBundleVersion":"20","platform":"IOS"},"relationships":{"app":{"data":{"id":"6770482363","type":"apps"}},"deliveryNotifications":{"data":[{"id":"${notification}","type":"deliveryNotifications"}]}},"type":"builds"},"included":[{"attributes":{"deliveryMechanism":"APNS","deviceId":"052985F22E06A4036F452C2F57CF266B7C5FB2833CD1FF71EED09CD8CC1437D1","environment":"PRODUCTION","sourceApplication":"TRANSPORTER"},"id":"${notification}","type":"deliveryNotifications"}]}
========================================
2026-07-17 00:36:13.040 DEBUG: [ContentDelivery.Uploader.A1BD4F840] Executing: /usr/bin/log stream --predicate process contains "Transporter" and subsystem == "com.apple.network" --debug --info --style compact
2026-07-17 00:36:13.406 DEBUG: [ContentDelivery.Uploader.A1E594A80] Download task 1 sent 526 bytes (526 of 526 bytes sent).
2026-07-17 00:36:13.975 DEBUG: [ContentDelivery.Uploader.A1CD6E3C0] Download task 1 did write 5446 bytes.
2026-07-17 00:36:13.976 DEBUG: [ContentDelivery.Uploader.A1CD6E3C0] Download task 1 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_xFe5IZ.tmp
2026-07-17 00:36:13.977 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CREATE BUILD (ASSET_UPLOAD) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds
 status code: 201 (created)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 699;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:36:13 GMT";
    Location = "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:06:13 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 308;
    "apple-tk" = false;
    b3 = "77fcb564d5c1482c02904e06153fe2ba-57463073467b88be";
    "x-apple-jingle-correlation-key" = O76LKZGVYFECYAUQJYDBKP7CXI;
    "x-apple-request-uuid" = "77fcb564-d5c1-482c-0290-4e06153fe2ba";
    "x-b3-parentspanid" = 278ef786877f496b;
    "x-b3-spanid" = 57463073467b88be;
    "x-b3-traceid" = a94612da6ebabbbf;
    "x-daiquiri-debug-worker-pid" = "105980, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338001:mr47p00it-qujn04120302:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3542;";
}
    httpBody: {
  "data" : {
    "type" : "builds",
    "id" : "5965e0e3-71f6-4a2d-a876-2c2c704d2362",
    "attributes" : {
      "version" : "20",
      "uploadedDate" : null,
      "processingState" : null,
      "processingErrors" : null,
      "buildProcessingState" : null
    },
    "relationships" : {
      "app" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/app",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/app",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=app"
        }
      },
      "buildDeliveryFiles" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/buildDeliveryFiles",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/buildDeliveryFiles",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=buildDeliveryFiles"
        }
      },
      "deliveryNotifications" : {
        "meta" : {
          "paging" : {
            "total" : 1,
            "limit" : 10
          }
        },
        "data" : [ {
          "type" : "deliveryNotifications",
          "id" : "01a81a3c-5f66-4cad-91e7-67a581322e31"
        } ],
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/deliveryNotifications",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/deliveryNotifications",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=deliveryNotifications"
        }
      },
      "buildAssetDescription" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/buildAssetDescription",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/buildAssetDescription",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=buildAssetDescription"
        }
      },
      "buildAsset" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/buildAsset",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/buildAsset",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=buildAsset"
        }
      },
      "buildAssetSpi" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/relationships/buildAssetSpi",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362/buildAssetSpi",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362?include=buildAssetSpi"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362"
    }
  },
  "included" : [ {
    "type" : "deliveryNotifications",
    "id" : "01a81a3c-5f66-4cad-91e7-67a581322e31",
    "attributes" : {
      "deliveryMechanism" : "APNS",
      "deviceId" : "052985F22E06A4036F452C2F57CF266B7C5FB2833CD1FF71EED09CD8CC1437D1",
      "sourceApplication" : "TRANSPORTER",
      "environment" : "PRODUCTION"
    }
  } ],
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds"
  }
}
=======================================
2026-07-17 00:36:13.978 DEBUG: [ContentDelivery.Uploader.A1E594780] Received build ID: 5965e0e3-71f6-4a2d-a876-2c2c704d2362
2026-07-17 00:36:13.980 DEBUG: [ContentDelivery.Uploader.A1E594780] Running state machine...
2026-07-17 00:36:13.980 DEBUG: [ContentDelivery.Uploader.A1E594780] Running state 'CDUploaderStateBegin'...
2026-07-17 00:36:13.981 DEBUG: [ContentDelivery.Uploader.A1E594780] Saving uploader state (CDUploaderStateBegin) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:13.985 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:36:13.986 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Making copy of ‘Evolve.ipa’…
2026-07-17 00:36:13.987 DEBUG: [ContentDelivery.Uploader.A1E594780] Copied '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/itmsps/3E7BBC32-B84B-4C8D-B311-AF8684F41883.itmsp/Evolve.ipa' to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.cds/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Evolve.ipa'.
2026-07-17 00:36:13.989 DEBUG: [ContentDelivery.Uploader.A1E594780] Uploading file: Evolve.ipa
           File size: 44100329
            Apple ID: 6770482363
Short version string: 1.1.2
      Version string: 20
            Platform: iOS App
2026-07-17 00:36:13.989 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Preparing to upload ‘Evolve.ipa’…
2026-07-17 00:36:13.990 DEBUG: [ContentDelivery.Uploader.A1E594780] Running state 'CDUploaderStateComputeAssetChecksum'...
2026-07-17 00:36:13.990 DEBUG: [ContentDelivery.Uploader.A1E594780] Saving uploader state (CDUploaderStateComputeAssetChecksum) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:13.992 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:36:14.161 DEBUG: [ContentDelivery.Uploader.A1E594780] Estimated part size: 5242880
Part checksums:(
    D29A6132D530952986408E1640D3B9A7,
    E5744E45166E1B682A41344C10B2E188,
    5E79BCA205A716645DC1958EE6C3A539,
    B8303D42F7F48F20A491FC48C1AB8151,
    7A775B14D1325E6BDF1598248DFF7BCE,
    4CDC710C7528C5DB8BC59A4547906834,
    072233F66566B89CB2030B181395DC73,
    7509F6DB4A3282166D841BA79CF6BBC2,
    6FA48C34EFEA9D54345DA2453D1ACFDE
)
2026-07-17 00:36:14.161 DEBUG: [ContentDelivery.Uploader.A1E594780] Running state 'CDUploaderStateRequestCreateContainer'...
2026-07-17 00:36:14.161 DEBUG: [ContentDelivery.Uploader.A1E594780] Saving uploader state (CDUploaderStateRequestCreateContainer) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:14.162 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:36:14.163 DEBUG: [ContentDelivery.Uploader.A1E594780] Running state 'CDUploaderStateUploadAssetDescription'...
2026-07-17 00:36:14.163 DEBUG: [ContentDelivery.Uploader.A1E594780] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:14.164 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:36:14.164 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Analysing package…
2026-07-17 00:36:14.164 DEBUG: [ContentDelivery.Uploader.A1E594780] myBundlePath: /Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework
2026-07-17 00:36:14.166 DEBUG: [ContentDelivery.Uploader.A1E594780] Searching for swinfo at: /Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo
2026-07-17 00:36:14.166 DEBUG: [ContentDelivery.Uploader.A1E594780] Calling swinfo at '/Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo'.
2026-07-17 00:36:14.167 DEBUG: [ContentDelivery.Uploader.A1E594780] Executing: /Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo -f /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.cds/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Evolve.ipa --extra-args /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/swinfo-extra-args-8E99D03C-BA2F-4CB6-BD67-BC48C32C6A4F.plist --platform ios -o /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml --plistFormat binary --output-spi
2026-07-17 00:36:25.264 DEBUG: [ContentDelivery.Uploader.A1E594780] Task ‘CDTask’ did terminate in ‘CDSwinfoCommandExecutor’ with exit code 0.
2026-07-17 00:36:25.265 DEBUG: [ContentDelivery.Uploader.A1E594780] Finished: '/Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo -f /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.cds/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Evolve.ipa --extra-args /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/swinfo-extra-args-8E99D03C-BA2F-4CB6-BD67-BC48C32C6A4F.plist --platform ios -o /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml --plistFormat binary --output-spi' with status 0
2026-07-17 00:36:25.265 DEBUG: [ContentDelivery.Uploader.A1E594780] *** /Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo
stdout: spi-output-file: /var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip

2026-07-17 00:36:25.265 DEBUG: [ContentDelivery.Uploader.A1E594780] dealloc CDSAbstractToolExecutor (CDSwinfoCommandExecutor), cdTask=/Applications/Transporter.app/Contents/Frameworks/ContentDelivery.framework/Resources/swinfo -f /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.cds/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Evolve.ipa --extra-args /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/swinfo-extra-args-8E99D03C-BA2F-4CB6-BD67-BC48C32C6A4F.plist --platform ios -o /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml --plistFormat binary --output-spi
2026-07-17 00:36:25.266 DEBUG: [ContentDelivery.Uploader.A1E594780] Asset description file: /Users/simo/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml
2026-07-17 00:36:25.266 DEBUG: [ContentDelivery.Uploader.A1E594780] SPI file: /var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip
2026-07-17 00:36:25.274 DEBUG: [ContentDelivery.Uploader.A1E594780] Creating container for asset description.
2026-07-17 00:36:25.274 DEBUG: [ContentDelivery.Uploader.A1E594780] Getting upload instructions for asset description.
2026-07-17 00:36:25.277 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
RETRIEVE UPLOAD OPERATIONS (UPLOADING ASSET DESCRIPTION) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles
     timeout: 900 seconds
      method: POST
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Length" = 368;
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:36:25Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABB+4xkKhKIkDdYmyttb1p5AgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: {"data":{"attributes":{"assetType":"ASSET_DESCRIPTION","fileName":"asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml","fileSize":2333781,"sourceFileChecksum":"2DFB31904CBC016D6A6D8967C566EF3E","uti":"com.apple.binary-property-list"},"relationships":{"build":{"data":{"id":"5965e0e3-71f6-4a2d-a876-2c2c704d2362","type":"builds"}}},"type":"buildDeliveryFiles"}}
========================================
2026-07-17 00:36:25.278 DEBUG: [ContentDelivery.Uploader.A1E5954C0] Download task 2 sent 368 bytes (368 of 368 bytes sent).
2026-07-17 00:36:25.809 DEBUG: [ContentDelivery.Uploader.A1E530F80] Download task 2 did write 2763 bytes.
2026-07-17 00:36:25.811 DEBUG: [ContentDelivery.Uploader.A1E597300] Download task 2 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_Jl9mTD.tmp
2026-07-17 00:36:25.812 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
RETRIEVE UPLOAD OPERATIONS (UPLOADING ASSET DESCRIPTION) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles
 status code: 201 (created)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 1099;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:36:25 GMT";
    Location = "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:06:25 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 336;
    "apple-tk" = false;
    b3 = "bbf523f1c583c17a13a12790eb7a3e59-4cebb51e47cfa574";
    "x-apple-jingle-correlation-key" = XP2SH4OFQPAXUE5BE6IOW6R6LE;
    "x-apple-request-uuid" = "bbf523f1-c583-c17a-13a1-2790eb7a3e59";
    "x-b3-parentspanid" = d749c660cd97f19e;
    "x-b3-spanid" = 4cebb51e47cfa574;
    "x-b3-traceid" = 4d44d4fee9c5bfd2;
    "x-daiquiri-debug-worker-pid" = "3493, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338002:mr47p00it-qujn02122102:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3545;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f",
    "attributes" : {
      "assetType" : "ASSET_DESCRIPTION",
      "fileSize" : 2333781,
      "fileName" : "asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml",
      "sourceFileChecksum" : "2DFB31904CBC016D6A6D8967C566EF3E",
      "sequentialChecksum" : null,
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/a03fe174-90b5-431b-ac11-9e7f722da343",
      "uploadOperations" : [ {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/3TpkfaasCiEvdArODWDQJC8g9nbITN52k6vJQRne4Vs_U003d-1784241385545?partNumber=1&uploadId=c74d3850-8166-11f1-8f86-6e25f4c44e0b&apple-asset-repo-correlation-key=XP2SH4OFQPAXUE5BE6IOW6R6LE&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223625Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=05ddde97561a588b96a693b9d118ec0a6d68b0730ed42331f9fb9b39604623c5",
        "length" : 2333781,
        "offset" : 0,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:36:25.725-07:00",
        "partNumber" : 1,
        "entityTag" : null
      } ],
      "uti" : "com.apple.binary-property-list",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "AWAITING_UPLOAD"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles"
  }
}
=======================================
2026-07-17 00:36:25.813 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Sending analysis to App Store Connect…
2026-07-17 00:36:25.813 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
UPLOADING ASSET DESCRIPTION
=======================================
2026-07-17 00:36:25.818 DEBUG: [ContentDelivery.Uploader.A1E594780] Created the temporary directory '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:25.821 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 1 still needs to be uploaded (2333781 bytes).
2026-07-17 00:36:25.821 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 1 will expire on 2026-07-24T00:36:25.725000+02:00.
2026-07-17 00:36:25.834 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote part 1 to temp file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-1.tmp'.
2026-07-17 00:36:25.835 DEBUG: [ContentDelivery.Uploader.A1E594780] Adding upload task for part 1.
2026-07-17 00:36:25.836 DEBUG: [ContentDelivery.Uploader.A1E594780] Waiting for 1 upload task to finish.
2026-07-17 00:36:26.277 DEBUG: [ContentDelivery.Uploader.A1E597300] PROGRESS - PART 1 (2097152) - 'asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml' 89.86% (2097152/2333781)
2026-07-17 00:36:27.212 DEBUG: [ContentDelivery.Uploader.A1E597300] PROGRESS - PART 1 (236629) - 'asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml' 100.00% (2333781/2333781)
2026-07-17 00:36:27.871 DEBUG: [ContentDelivery.Uploader.A1CD6E200] COMPLETED - PART 1 - asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml - eTag: "2DFB31904CBC016D6A6D8967C566EF3E"
2026-07-17 00:36:27.873 DEBUG: [ContentDelivery.Uploader.A1CD6E200] Removed temporary part file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-1.tmp'.
2026-07-17 00:36:27.874 DEBUG: [ContentDelivery.Uploader.A1CD6E200] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:27.876 DEBUG: [ContentDelivery.Uploader.A1CD6E200] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:36:27.877 DEBUG: [ContentDelivery.Uploader.A1CD6E200] All parts have been uploaded.
2026-07-17 00:36:27.877 DEBUG: [ContentDelivery.Uploader.A1E594780] Time to transfer: 1.378 seconds
2026-07-17 00:36:27.878 DEBUG: [ContentDelivery.Uploader.A1E594780] Removed temporary directory '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:36:27.882 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_DESCRIPTION) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f
     timeout: 900 seconds
      method: GET
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:36:27Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABB+4xkKhKIkDdYmyttb1p5AgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: 
========================================
2026-07-17 00:36:28.451 DEBUG: [ContentDelivery.Uploader.A1CD6E200] Download task 4 did write 2830 bytes.
2026-07-17 00:36:28.452 DEBUG: [ContentDelivery.Uploader.A1CD6E200] Download task 4 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_JUzi0J.tmp
2026-07-17 00:36:28.453 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_DESCRIPTION) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f
 status code: 200 (no error)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 1096;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:36:28 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:06:28 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 253;
    "apple-tk" = false;
    b3 = "a0db0a8e9098ca65b9bbda6fabc282fd-9bdf6373e7208e78";
    "x-apple-jingle-correlation-key" = UDNQVDUQTDFGLON33JX2XQUC7U;
    "x-apple-request-uuid" = "a0db0a8e-9098-ca65-b9bb-da6fabc282fd";
    "x-b3-parentspanid" = 347996282b992462;
    "x-b3-spanid" = 9bdf6373e7208e78;
    "x-b3-traceid" = 46466a95b0e3d886;
    "x-daiquiri-debug-worker-pid" = "106272, 24193, 6164";
    "x-daiquiri-instance" = "daiquiri:31338002:pv52p00it-qujn10213502:7987:26RELEASE107:daiquiri-amp-all-l7shared-int-001-pv, daiquiri:33624002:pv50p00it-hyhk12033901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-pv, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3543;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f",
    "attributes" : {
      "assetType" : "ASSET_DESCRIPTION",
      "fileSize" : 2333781,
      "fileName" : "asset-description-75F9A2FF-3D36-4B5B-94DA-95FAC12DAD6C.xml",
      "sourceFileChecksum" : "2DFB31904CBC016D6A6D8967C566EF3E",
      "sequentialChecksum" : null,
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/a03fe174-90b5-431b-ac11-9e7f722da343",
      "uploadOperations" : [ {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/3TpkfaasCiEvdArODWDQJC8g9nbITN52k6vJQRne4Vs_U003d-1784241385545?partNumber=1&uploadId=c74d3850-8166-11f1-8f86-6e25f4c44e0b&apple-asset-repo-correlation-key=XP2SH4OFQPAXUE5BE6IOW6R6LE&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223625Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=05ddde97561a588b96a693b9d118ec0a6d68b0730ed42331f9fb9b39604623c5",
        "length" : 2333781,
        "offset" : 0,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:36:25.725-07:00",
        "partNumber" : 1,
        "entityTag" : "2DFB31904CBC016D6A6D8967C566EF3E"
      } ],
      "uti" : "com.apple.binary-property-list",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "AWAITING_UPLOAD"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f"
  }
}
=======================================
2026-07-17 00:36:28.454 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Waiting for App Store Connect analysis response…
2026-07-17 00:36:28.454 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING ASSET DESCRIPTION)
=======================================
2026-07-17 00:36:28.458 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING ASSET DESCRIPTION) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f
     timeout: 900 seconds
      method: PATCH
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Length" = 113;
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:36:28Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABB+4xkKhKIkDdYmyttb1p5AgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: {"data":{"attributes":{"uploaded":true},"id":"4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f","type":"buildDeliveryFiles"}}
========================================
2026-07-17 00:36:28.460 DEBUG: [ContentDelivery.Uploader.A1B9E0D40] Download task 5 sent 113 bytes (113 of 113 bytes sent).
2026-07-17 00:37:10.227 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 5 did write 428 bytes.
2026-07-17 00:37:10.228 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 5 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_vX34Ai.tmp
2026-07-17 00:37:10.229 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING ASSET DESCRIPTION) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/4c8f8d0d-3c1d-4a63-8db1-c9410777fa6f
 status code: 409 (conflict)
 httpHeaders: {
    "Content-Length" = 428;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:37:10 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:06:28 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 41567;
    "apple-tk" = false;
    b3 = "541adbf2d627d46203e04f78474d7d25-3037009ea2baeef9";
    "x-apple-jingle-correlation-key" = KQNNX4WWE7KGEA7AJ54EOTL5EU;
    "x-apple-request-uuid" = "541adbf2-d627-d462-03e0-4f78474d7d25";
    "x-b3-parentspanid" = 1dc583fbb321159f;
    "x-b3-spanid" = 3037009ea2baeef9;
    "x-b3-traceid" = a4479bb8ea0964cc;
    "x-daiquiri-debug-worker-pid" = "105980, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338001:mr47p00it-qujn04120302:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3538;";
}
    httpBody: {
  "errors" : [ {
    "id" : "6fdd8441-3c28-4944-a92f-860e9580ee0f",
    "status" : "409",
    "code" : "STATE_ERROR.VALIDATION_ERROR",
    "title" : "Validation failed",
    "detail" : "Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect."
  } ]
}
=======================================
2026-07-17 00:37:10.231 DEBUG: [ContentDelivery.Uploader.A1E594780] Uploading swinfo errors: Validation failed (409) Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect. (ID: 6fdd8441-3c28-4944-a92f-860e9580ee0f)
   NSUnderlyingError : Validation failed (-19241) Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect.
      status : 409
      detail : Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect.
      id : 6fdd8441-3c28-4944-a92f-860e9580ee0f
      code : STATE_ERROR.VALIDATION_ERROR
      title : Validation failed
   iris-code : STATE_ERROR.VALIDATION_ERROR
2026-07-17 00:37:10.232 DEBUG: [ContentDelivery.Uploader.A1E594780] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:10.235 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:37:10.321 DEBUG: [ContentDelivery.Uploader.A1E594780] Creating container for SPI analysis.
2026-07-17 00:37:10.321 DEBUG: [ContentDelivery.Uploader.A1E594780] Getting upload instructions for SPI analysis.
2026-07-17 00:37:10.325 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
RETRIEVE UPLOAD OPERATIONS (UPLOADING SPI ANALYSIS) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles
     timeout: 900 seconds
      method: POST
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Length" = 364;
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:37:10Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABDVOLorRvPle0g/f36LvmBEgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: {"data":{"attributes":{"assetType":"ASSET_SPI","fileName":"DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip","fileSize":16221725,"sourceFileChecksum":"534C5FFF31022DB14E7033F232ADE2E4","uti":"com.pkware.zip-archive"},"relationships":{"build":{"data":{"id":"5965e0e3-71f6-4a2d-a876-2c2c704d2362","type":"builds"}}},"type":"buildDeliveryFiles"}}
========================================
2026-07-17 00:37:10.326 DEBUG: [ContentDelivery.Uploader.A1E597300] Download task 6 sent 364 bytes (364 of 364 bytes sent).
2026-07-17 00:37:10.906 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 6 did write 5579 bytes.
2026-07-17 00:37:10.909 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 6 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_jQX4k1.tmp
2026-07-17 00:37:10.910 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
RETRIEVE UPLOAD OPERATIONS (UPLOADING SPI ANALYSIS) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles
 status code: 201 (created)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 1319;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:37:10 GMT";
    Location = "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:07:10 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 388;
    "apple-tk" = false;
    b3 = "b349fd071070b827cb41ce1e59e5e6c5-40ae03952fca418b";
    "x-apple-jingle-correlation-key" = WNE72BYQOC4CPS2BZYPFTZPGYU;
    "x-apple-request-uuid" = "b349fd07-1070-b827-cb41-ce1e59e5e6c5";
    "x-b3-parentspanid" = ee251609ea99068f;
    "x-b3-spanid" = 40ae03952fca418b;
    "x-b3-traceid" = c6bd6ce1ba1bf240;
    "x-daiquiri-debug-worker-pid" = "105980, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338001:mr47p00it-qujn04120302:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3536;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "01d696a8-b7bc-4be5-8893-b4ee6400d69a",
    "attributes" : {
      "assetType" : "ASSET_SPI",
      "fileSize" : 16221725,
      "fileName" : "DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip",
      "sourceFileChecksum" : "534C5FFF31022DB14E7033F232ADE2E4",
      "sequentialChecksum" : null,
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/ac78e344-983a-47a7-bf8b-f109b0962eaa",
      "uploadOperations" : [ {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=2&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=f90345f7d558aa14d201232e5b9c20acab5ca27bd3466b4ef02535506b0b5a23",
        "length" : 5242880,
        "offset" : 5242880,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.8-07:00",
        "partNumber" : 2,
        "entityTag" : null
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=3&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=152cc33923e20bb72ee5cb291b81cdac27510784e3b2b2c3922f2d5fb8ba96da",
        "length" : 5242880,
        "offset" : 10485760,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.801-07:00",
        "partNumber" : 3,
        "entityTag" : null
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=1&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=aa0acbf1f26bca4c128580289b27869500863dc4921c621e21f63fb8d732f2ac",
        "length" : 5242880,
        "offset" : 0,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.8-07:00",
        "partNumber" : 1,
        "entityTag" : null
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=4&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=aa9a234cbdba00312e160eced3f92594d06f97342da1385b91aa5af8effdb5d5",
        "length" : 493085,
        "offset" : 15728640,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.801-07:00",
        "partNumber" : 4,
        "entityTag" : null
      } ],
      "uti" : "com.pkware.zip-archive",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "AWAITING_UPLOAD"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles"
  }
}
=======================================
2026-07-17 00:37:10.911 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Sending SPI analysis to App Store Connect…
2026-07-17 00:37:10.912 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
UPLOADING SPI ANALYSIS
=======================================
2026-07-17 00:37:10.915 DEBUG: [ContentDelivery.Uploader.A1E594780] Created the temporary directory '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:10.916 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 1 still needs to be uploaded (5242880 bytes).
2026-07-17 00:37:10.916 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 1 will expire on 2026-07-24T00:37:10.800000+02:00.
2026-07-17 00:37:10.917 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 2 still needs to be uploaded (5242880 bytes).
2026-07-17 00:37:10.917 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 2 will expire on 2026-07-24T00:37:10.800000+02:00.
2026-07-17 00:37:10.917 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 3 still needs to be uploaded (5242880 bytes).
2026-07-17 00:37:10.917 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 3 will expire on 2026-07-24T00:37:10.801000+02:00.
2026-07-17 00:37:10.918 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 4 still needs to be uploaded (493085 bytes).
2026-07-17 00:37:10.918 DEBUG: [ContentDelivery.Uploader.A1E594780] Part 4 will expire on 2026-07-24T00:37:10.801000+02:00.
2026-07-17 00:37:10.930 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote part 1 to temp file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-1.tmp'.
2026-07-17 00:37:10.930 DEBUG: [ContentDelivery.Uploader.A1E594780] Adding upload task for part 1.
2026-07-17 00:37:10.942 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote part 2 to temp file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-2.tmp'.
2026-07-17 00:37:10.943 DEBUG: [ContentDelivery.Uploader.A1E594780] Adding upload task for part 2.
2026-07-17 00:37:10.955 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote part 3 to temp file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-3.tmp'.
2026-07-17 00:37:10.955 DEBUG: [ContentDelivery.Uploader.A1E594780] Adding upload task for part 3.
2026-07-17 00:37:10.957 DEBUG: [ContentDelivery.Uploader.A1E594780] Wrote part 4 to temp file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-4.tmp'.
2026-07-17 00:37:10.957 DEBUG: [ContentDelivery.Uploader.A1E594780] Adding upload task for part 4.
2026-07-17 00:37:10.959 DEBUG: [ContentDelivery.Uploader.A1E594780] Waiting for 4 upload tasks to finish.
2026-07-17 00:37:11.297 DEBUG: [ContentDelivery.Uploader.A1BD29D00] PROGRESS - PART 4 (493085) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 100.00% (493085/493085)
2026-07-17 00:37:11.377 DEBUG: [ContentDelivery.Uploader.A1E5954C0] PROGRESS - PART 2 (2097152) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 40.00% (2097152/5242880)
2026-07-17 00:37:11.398 DEBUG: [ContentDelivery.Uploader.A1B8C6400] PROGRESS - PART 1 (2097152) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 40.00% (2097152/5242880)
2026-07-17 00:37:11.404 DEBUG: [ContentDelivery.Uploader.A1B8C6400] PROGRESS - PART 3 (2097152) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 40.00% (2097152/5242880)
2026-07-17 00:37:12.079 DEBUG: [ContentDelivery.Uploader.A1E972E40] PROGRESS - PART 1 (1048576) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 60.00% (3145728/5242880)
2026-07-17 00:37:12.151 DEBUG: [ContentDelivery.Uploader.A1BD29D00] PROGRESS - PART 2 (1048576) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 60.00% (3145728/5242880)
2026-07-17 00:37:12.177 DEBUG: [ContentDelivery.Uploader.A1E972E40] PROGRESS - PART 3 (2097152) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 80.00% (4194304/5242880)
2026-07-17 00:37:12.209 DEBUG: [ContentDelivery.Uploader.A1E972E40] PROGRESS - PART 1 (2097152) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 100.00% (5242880/5242880)
2026-07-17 00:37:12.217 DEBUG: [ContentDelivery.Uploader.A1E5954C0] PROGRESS - PART 3 (1048576) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 100.00% (5242880/5242880)
2026-07-17 00:37:12.276 DEBUG: [ContentDelivery.Uploader.A1BD29D00] PROGRESS - PART 2 (1048576) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 80.00% (4194304/5242880)
2026-07-17 00:37:12.308 DEBUG: [ContentDelivery.Uploader.A1BD29D00] PROGRESS - PART 2 (1048576) - 'DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip' 100.00% (5242880/5242880)
2026-07-17 00:37:12.453 DEBUG: [ContentDelivery.Uploader.A1B8C6400] COMPLETED - PART 4 - DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip - eTag: "00F87FE579BFADDE4A7C297CB0FF79AB"
2026-07-17 00:37:12.455 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Removed temporary part file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-4.tmp'.
2026-07-17 00:37:12.455 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:12.458 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:37:12.458 DEBUG: [ContentDelivery.Uploader.A1B8C6400] There are 3 parts remaining to upload.
2026-07-17 00:37:12.778 DEBUG: [ContentDelivery.Uploader.A1B8C6400] COMPLETED - PART 1 - DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip - eTag: "15B057017D38E4DA1A4F744CF78E0AED"
2026-07-17 00:37:12.781 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Removed temporary part file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-1.tmp'.
2026-07-17 00:37:12.781 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:12.784 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:37:12.784 DEBUG: [ContentDelivery.Uploader.A1B8C6400] There are 2 parts remaining to upload.
2026-07-17 00:37:12.829 DEBUG: [ContentDelivery.Uploader.A1BD29D00] COMPLETED - PART 2 - DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip - eTag: "95A80FCD9FC14A0E1F2A11498EA51D1C"
2026-07-17 00:37:12.831 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Removed temporary part file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-2.tmp'.
2026-07-17 00:37:12.831 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:12.834 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:37:12.834 DEBUG: [ContentDelivery.Uploader.A1BD29D00] There is one part remaining to upload.
2026-07-17 00:37:13.190 DEBUG: [ContentDelivery.Uploader.A1BD29D00] COMPLETED - PART 3 - DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip - eTag: "01E8BDEB932AA0AF59B346ECFC7547C3"
2026-07-17 00:37:13.193 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Removed temporary part file '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C/Part-3.tmp'.
2026-07-17 00:37:13.193 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Saving uploader state (CDUploaderStateUploadAssetDescription) for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:13.196 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Wrote state to '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Application Support/com.apple.TransporterApp/CDUploads/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C.plist'.
2026-07-17 00:37:13.196 DEBUG: [ContentDelivery.Uploader.A1BD29D00] All parts have been uploaded.
2026-07-17 00:37:13.197 DEBUG: [ContentDelivery.Uploader.A1E594780] Time to transfer: 1.351 seconds
2026-07-17 00:37:13.197 DEBUG: [ContentDelivery.Uploader.A1E594780] Removed temporary directory '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.TransporterApp/tmp/com.apple.cds.vbtx/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:13.201 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_SPI) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
     timeout: 900 seconds
      method: GET
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:37:13Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABDVOLorRvPle0g/f36LvmBEgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: 
========================================
2026-07-17 00:37:13.803 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 11 did write 5736 bytes.
2026-07-17 00:37:13.804 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 11 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_eeVruq.tmp
2026-07-17 00:37:13.805 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_SPI) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
 status code: 200 (no error)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 1417;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:37:13 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:07:13 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 290;
    "apple-tk" = false;
    b3 = "436d51d33c78b187ad5509633e0ec2b6-88b3947ed520e064";
    "x-apple-jingle-correlation-key" = INWVDUZ4PCYYPLKVBFRT4DWCWY;
    "x-apple-request-uuid" = "436d51d3-3c78-b187-ad55-09633e0ec2b6";
    "x-b3-parentspanid" = e641501bdda66df2;
    "x-b3-spanid" = 88b3947ed520e064;
    "x-b3-traceid" = 8791dfca338eb41f;
    "x-daiquiri-debug-worker-pid" = "122850, 24208, 6164";
    "x-daiquiri-instance" = "daiquiri:31338001:pv52p00it-qujn08063302:7987:26RELEASE107:daiquiri-amp-all-l7shared-int-001-pv, daiquiri:33624002:pv50p00it-hyhk12033901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-pv, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3541;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "01d696a8-b7bc-4be5-8893-b4ee6400d69a",
    "attributes" : {
      "assetType" : "ASSET_SPI",
      "fileSize" : 16221725,
      "fileName" : "DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip",
      "sourceFileChecksum" : "534C5FFF31022DB14E7033F232ADE2E4",
      "sequentialChecksum" : null,
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/ac78e344-983a-47a7-bf8b-f109b0962eaa",
      "uploadOperations" : [ {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=4&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=aa9a234cbdba00312e160eced3f92594d06f97342da1385b91aa5af8effdb5d5",
        "length" : 493085,
        "offset" : 15728640,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.801-07:00",
        "partNumber" : 4,
        "entityTag" : "00F87FE579BFADDE4A7C297CB0FF79AB"
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=1&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=aa0acbf1f26bca4c128580289b27869500863dc4921c621e21f63fb8d732f2ac",
        "length" : 5242880,
        "offset" : 0,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.8-07:00",
        "partNumber" : 1,
        "entityTag" : "15B057017D38E4DA1A4F744CF78E0AED"
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=2&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=f90345f7d558aa14d201232e5b9c20acab5ca27bd3466b4ef02535506b0b5a23",
        "length" : 5242880,
        "offset" : 5242880,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.8-07:00",
        "partNumber" : 2,
        "entityTag" : "95A80FCD9FC14A0E1F2A11498EA51D1C"
      }, {
        "method" : "PUT",
        "url" : "https://northamerica-1.object-storage.apple.com/itms-assets-prod-200001/PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/LdOFdk1iQhF882eUq7Pr0msCEE9Jz-n31w1-sr5BTuA_U003d-1784241430627?partNumber=3&uploadId=e22b93b0-8166-11f1-abf5-7ec21b9d403d&apple-asset-repo-correlation-key=WNE72BYQOC4CPS2BZYPFTZPGYU&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T223710Z&X-Amz-SignedHeaders=host&X-Amz-Credential=PKIAI0ZGNAD8WKMSOOX0%2F20260716%2Fnorthamerica-1%2Fs3%2Faws4_request&X-Amz-Expires=604800&X-Amz-Signature=152cc33923e20bb72ee5cb291b81cdac27510784e3b2b2c3922f2d5fb8ba96da",
        "length" : 5242880,
        "offset" : 10485760,
        "requestHeaders" : [ {
          "name" : "Content-Type",
          "value" : "application/octet-stream"
        } ],
        "expiration" : "2026-07-23T15:37:10.801-07:00",
        "partNumber" : 3,
        "entityTag" : "01E8BDEB932AA0AF59B346ECFC7547C3"
      } ],
      "uti" : "com.pkware.zip-archive",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "AWAITING_UPLOAD"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
  }
}
=======================================
2026-07-17 00:37:13.806 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Waiting for App Store Connect SPI analysis response…
2026-07-17 00:37:13.807 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING SPI ANALYSIS)
=======================================
2026-07-17 00:37:13.810 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING SPI ANALYSIS) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
     timeout: 900 seconds
      method: PATCH
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Length" = 113;
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:37:13Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABDVOLorRvPle0g/f36LvmBEgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: {"data":{"attributes":{"uploaded":true},"id":"01d696a8-b7bc-4be5-8893-b4ee6400d69a","type":"buildDeliveryFiles"}}
========================================
2026-07-17 00:37:13.812 DEBUG: [ContentDelivery.Uploader.A1BD29D00] Download task 12 sent 113 bytes (113 of 113 bytes sent).
2026-07-17 00:37:30.290 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Download task 12 did write 1896 bytes.
2026-07-17 00:37:30.291 DEBUG: [ContentDelivery.Uploader.A1B8C6400] Download task 12 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_wJ6l7W.tmp
2026-07-17 00:37:30.292 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
CHANGE UPLOAD STATE TO COMPLETE (UPLOADING SPI ANALYSIS) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
 status code: 200 (no error)
 httpHeaders: {
    "Content-Length" = 1896;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:37:30 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:07:13 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 16244;
    "apple-tk" = false;
    b3 = "7b6d55cff1eac7d69913d25073409b27-36e6eebbba7e1b3a";
    "x-apple-jingle-correlation-key" = PNWVLT7R5LD5NGIT2JIHGQE3E4;
    "x-apple-request-uuid" = "7b6d55cf-f1ea-c7d6-9913-d25073409b27";
    "x-b3-parentspanid" = 253231a94c017951;
    "x-b3-spanid" = 36e6eebbba7e1b3a;
    "x-b3-traceid" = bb4d5d42db485473;
    "x-daiquiri-debug-worker-pid" = "122850, 24208, 6164";
    "x-daiquiri-instance" = "daiquiri:31338001:pv52p00it-qujn08063302:7987:26RELEASE107:daiquiri-amp-all-l7shared-int-001-pv, daiquiri:33624002:pv50p00it-hyhk12033901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-pv, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3540;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "01d696a8-b7bc-4be5-8893-b4ee6400d69a",
    "attributes" : {
      "assetType" : "ASSET_SPI",
      "fileSize" : 16221725,
      "fileName" : "DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip",
      "sourceFileChecksum" : "534C5FFF31022DB14E7033F232ADE2E4",
      "sequentialChecksum" : "0c9d494567f84bde6fbc70d90b341e40-4-5242880",
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/ac78e344-983a-47a7-bf8b-f109b0962eaa",
      "uploadOperations" : null,
      "uti" : "com.pkware.zip-archive",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "COMPLETE"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
  }
}
=======================================
2026-07-17 00:37:30.293 DEBUG: [ContentDelivery.Uploader.A1E594780] 
========================================
Set ASSET_SPI status to COMPLETE
========================================
2026-07-17 00:37:30.294 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_SPI) REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
     timeout: 900 seconds
      method: GET
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:37:13Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABDVOLorRvPle0g/f36LvmBEgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: 
========================================
2026-07-17 00:37:30.632 DEBUG: [ContentDelivery.Uploader.A1E597300] Download task 13 did write 1896 bytes.
2026-07-17 00:37:30.633 DEBUG: [ContentDelivery.Uploader.A1E5954C0] Download task 13 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_Q46eCo.tmp
2026-07-17 00:37:30.634 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
GET UPLOAD STATE (ASSET_SPI) RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a
 status code: 200 (no error)
 httpHeaders: {
    "Content-Encoding" = gzip;
    "Content-Length" = 637;
    "Content-Type" = "application/json";
    Date = "Thu, 16 Jul 2026 22:37:30 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:07:30 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    Vary = "Accept-Encoding";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 123;
    "apple-tk" = false;
    b3 = "10ebfcf10286a4cc67913d482cec88fc-752c71b770e3e4ce";
    "x-apple-jingle-correlation-key" = CDV7Z4ICQ2SMYZ4RHVECZ3EI7Q;
    "x-apple-request-uuid" = "10ebfcf1-0286-a4cc-6791-3d482cec88fc";
    "x-b3-parentspanid" = dcd90a0c848c08bd;
    "x-b3-spanid" = 752c71b770e3e4ce;
    "x-b3-traceid" = 15e70666ffc3efb4;
    "x-daiquiri-debug-worker-pid" = "78043, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338003:mr47p00it-qujn05120301:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3539;";
}
    httpBody: {
  "data" : {
    "type" : "buildDeliveryFiles",
    "id" : "01d696a8-b7bc-4be5-8893-b4ee6400d69a",
    "attributes" : {
      "assetType" : "ASSET_SPI",
      "fileSize" : 16221725,
      "fileName" : "DTAppAnalyzerExtractorOutput-F38D323A-4E5C-437A-A8D4-18C8BF702128.zip",
      "sourceFileChecksum" : "534C5FFF31022DB14E7033F232ADE2E4",
      "sequentialChecksum" : "0c9d494567f84bde6fbc70d90b341e40-4-5242880",
      "assetToken" : "PurpleSource211/v4/d9/bb/3a/d9bb3aa3-e83b-1e77-899a-cb2435d7156d/ac78e344-983a-47a7-bf8b-f109b0962eaa",
      "uploadOperations" : null,
      "uti" : "com.pkware.zip-archive",
      "assetDeliveryState" : {
        "errors" : [ ],
        "warnings" : [ ],
        "state" : "COMPLETE"
      }
    },
    "relationships" : {
      "build" : {
        "links" : {
          "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/relationships/build",
          "related" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a/build",
          "include" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a?include=build"
        }
      }
    },
    "links" : {
      "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
    }
  },
  "links" : {
    "self" : "https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/buildDeliveryFiles/01d696a8-b7bc-4be5-8893-b4ee6400d69a"
  }
}
=======================================
2026-07-17 00:37:30.635 DEBUG: [ContentDelivery.Uploader.A1E594780] 
========================
DELETE DELIVERY BUILD ID
========================
2026-07-17 00:37:30.641 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
DELETE BUILD ID REQUEST:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362
     timeout: 900 seconds
      method: DELETE
 httpHeaders: {
    Accept = "application/json";
    "Accept-Language" = "en-GB";
    "Content-Type" = "application/json";
    "User-Agent" = "TransporterApp/1.4-14025 (Macintosh; macOS 26.5.1 25F80 (arm64)) ContentDelivery/26.30.2-173002";
    "X-Apple-App-Info" = "com.apple.gs.itunesconnect.auth";
    "X-Apple-GS-Token" = "**hidden value**";
    "X-Apple-I-Client-Time" = "2026-07-16T22:37:30Z";
    "X-Apple-I-Identity-Id" = "001723-08-86a1e8f9-0f18-4c8d-8367-a987477243f9";
    "X-Apple-I-Locale" = "en_IT";
    "X-Apple-I-MD" = "AAAABQAAABB6Ep6JYONqTNDoB29WNEgSgAAAAQ==";
    "X-Apple-I-MD-LU" = 82C3137DDE278878BC4364BA7DB20061D435C38AB40E3C8F953FB1A413041734;
    "X-Apple-I-MD-M" = "Y9wewDmHiKvAKeUa6fPuLBQ3Eb8a8uIcRrVxLBhTVET+i0i95blA9iz+mXzbfKjUO3/5DT8gO0XuSsW2";
    "X-Apple-I-MD-RINFO" = 84215040;
    "X-Apple-I-TimeZone" = CEST;
    "X-MMe-Client-Info" = "<Macmini9,1> <macOS;26.5.1;25F80> <com.apple.AuthKit/1 (com.apple.TransporterApp/14025)>";
    "X-Mme-Device-Id" = "28D65020-984E-51EE-A26E-47E57A827BD0";
    "x-connect-team-id" = "41e367cd-6fc9-447a-ae46-2ad5f0f63d92";
    "x-connect-team-type" = "CONTENT_PROVIDER";
}
    httpBody: 
========================================
2026-07-17 00:37:31.163 DEBUG: [ContentDelivery.Uploader.A1BD2B8C0] Download task 14 did write file: file:///var/folders/18/m1wjfwyx1lz2w3pv1n6kvnfm0000gn/T/CFNetworkDownload_2Nm1bd.tmp
2026-07-17 00:37:31.164 DEBUG: [ContentDelivery.Uploader.A1E594780] 
=======================================
DELETE BUILD ID RESPONSE:

         URL: https://contentdelivery.itunes.apple.com/MZContentDeliveryService/iris/provider/41e367cd-6fc9-447a-ae46-2ad5f0f63d92/v1/builds/5965e0e3-71f6-4a2d-a876-2c2c704d2362
 status code: 204 (no content)
 httpHeaders: {
    Date = "Thu, 16 Jul 2026 22:37:31 GMT";
    Server = "daiquiri/5";
    "Set-Cookie" = "dqsid=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODQyNDEzNzMsImp0aSI6ImdFcUxoSXJ6WnQzY1c5UE9tT3hHMkEifQ.-U3afyLmw4eIxZNldCttCcU0A_xm8CnV24KnW4bh5Z4; Max-Age=1800; Expires=Thu, 16 Jul 2026 23:07:30 GMT; Path=/; Secure; HTTPOnly";
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains";
    "apple-originating-system" = MZContentDeliveryService;
    "apple-seq" = "0.0";
    "apple-timing-app" = 304;
    "apple-tk" = false;
    b3 = "5dcbc562fd748051dcd12ab2174f208d-5dcf7e20a845522f";
    "x-apple-jingle-correlation-key" = LXF4KYX5OSAFDXGRFKZBOTZARU;
    "x-apple-request-uuid" = "5dcbc562-fd74-8051-dcd1-2ab2174f208d";
    "x-b3-parentspanid" = 16f3f287f67ee5fc;
    "x-b3-spanid" = 5dcf7e20a845522f;
    "x-b3-traceid" = 4a7936f38691699b;
    "x-daiquiri-debug-worker-pid" = "78043, 1852, 6164";
    "x-daiquiri-instance" = "daiquiri:11338003:mr47p00it-qujn05120301:7987:26HOTFIX26:daiquiri-amp-all-l7shared-int-001-mr, daiquiri:13624002:mr85p00it-hyhk03094901:7987:26HOTFIX26:daiquiri-amp-processing-shared-int-001-mr, daiquiri:18493001:mr85p00it-hyhk03154801:7987:26HOTFIX26:daiquiri-amp-all-shared-ext-001-mr";
    "x-daiquiri-rate-limit-timing-user" = 0;
    "x-daiquiri-rate-limit-user" = "user-hour-lim:3600;user-hour-rem:3534;";
}
    httpBody: 
=======================================
2026-07-17 00:37:31.165 DEBUG: [ContentDelivery.Uploader.A1E594780] BuildID '5965e0e3-71f6-4a2d-a876-2c2c704d2362' was deleted.
2026-07-17 00:37:31.168 DEBUG: [ContentDelivery.Uploader.A1E594780] Removed the temporary asset directory '~/Library/Group Containers/group.com.apple.contentdelivery/Library/Caches/com.apple.cds/com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:31.169 DEBUG: [ContentDelivery.Uploader.A1E594780] Removing uploader saved state for identifier 'com.apple.cds_8E1F4A70-7436-40F9-AB3E-64E5E30D1D4C'.
2026-07-17 00:37:31.170 DEBUG: [ContentDelivery.Uploader.A1E594780] Show Progress: Upload failed.
Validation failed
Invalid Export Compliance Code. The export compliance key value [] in the app's Info.plist doesn’t match the key value of the app’s export compliance documentation. To find the correct value, go to My Apps on App Store Connect. (ID: 6fdd8441-3c28-4944-a92f-860e9580ee0f)
2026-07-17 00:37:31.170 ERROR: [ContentDelivery.Uploader.A1E594780] 
=======================================
UPLOAD FAILED with 1 error
=======================================
2026-07-17 00:37:31.171 DEBUG: [ContentDelivery.Uploader.A1E594780] Log file path: ~/Library/Group Containers/group.com.apple.contentdelivery/Library/Logs/ContentDelivery/com.apple.TransporterApp/com.apple.TransporterApp_Upload_2026-07-17_00-36-13_030.txt
".

I've also inserted in the "TMP_IMAGES/**.png" some screenshot from app store connect if could help.

---

## 2026-07-17 — iOS export-compliance fix: manual re-upload required

The code fix is done (`ITSAppUsesNonExemptEncryption` → `false` in `mobile/ios/Runner/Info.plist`). On the Mac mini (full Xcode), you now need to:

1. Pull/sync the updated `mobile/ios/Runner/Info.plist`.
2. Rebuild the IPA (e.g. `flutter build ipa --release`, then archive/export in Xcode as usual).
3. Re-upload via Transporter.
   - Build 20 was auto-deleted server-side after the failed validation, so `1.1.2 (20)` should be reusable. If App Store Connect rejects it as "already used", bump the build number to 21 and rebuild.
4. NO App Store Connect changes are needed — do NOT upload encryption documentation. With the exempt declaration, the "Export Compliance" question is auto-answered and the build will validate cleanly.

NOTE (legal self-declaration): `false` = "app uses only exempt encryption." This is correct for Evolve (HTTPS + Apple crypto + Face ID + SQLCipher/AES-256, all standard/exempt). Confirm you're comfortable with that declaration before submitting.