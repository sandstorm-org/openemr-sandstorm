@0x973c2d307f855356;

using Spk = import "/sandstorm/package.capnp";
# This imports:
#   $SANDSTORM_HOME/latest/usr/include/sandstorm/package.capnp
# Check out that file to see the full, documented package definition format.

const pkgdef :Spk.PackageDefinition = (
  # The package definition. Note that the spk tool looks specifically for the
  # "pkgdef" constant.

  id = "82y6e9r4x1dthq3xhu76dtakq7mm3rr1wvwfkx10w50g3k0521eh",
  # Your app ID is actually its public key. The private key was placed in
  # your keyring. All updates must be signed with the same key.

  manifest = (
    # This manifest is included in your app package to tell Sandstorm
    # about your app.

    appTitle = (defaultText = "Open-EMR"),

    appVersion = 0,  # Increment this for every release.

    appMarketingVersion = (defaultText = "7.0.3"),
    # Human-readable representation of appVersion. Should match the way you
    # identify versions of your app in documentation and marketing.

    actions = [
      # Define your "new document" handlers here.
      ( nounPhrase = (defaultText = "instance"),
        command = .myCommand
        # The command to run when starting for the first time. (".myCommand"
        # is just a constant defined at the bottom of the file.)
      )
    ],

    continueCommand = .myCommand,
    # This is the command called to start your app back up after it has been
    # shut down for inactivity. Here we're using the same command as for
    # starting a new instance, but you could use different commands for each
    # case.

    metadata = (
      # Data which is not needed specifically to execute the app, but is useful
      # for purposes like marketing and display.  These fields are documented at
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#add-required-metadata
      # and (in deeper detail) in the sandstorm source code, in the Metadata section of
      # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/package.capnp
      icons = (
        # Various icons to represent the app in various contexts.
        #appGrid = (svg = embed "path/to/appgrid-128x128.svg"),
        #grain = (svg = embed "path/to/grain-24x24.svg"),
        #market = (svg = embed "path/to/market-150x150.svg"),
        #marketBig = (svg = embed "path/to/market-big-300x300.svg"),
      ),

      website = "http://www.open-emr.org",
      # This should be the app's main website url.

      codeUrl = "http://github.com/mbp-kg/openemr-sandstorm/",
      # URL of the app's source code repository, e.g. a GitHub URL.
      # Required if you specify a license requiring redistributing code, but optional otherwise.

      license = (openSource = gpl3),
      # The license this package is distributed under.  See
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#license

      categories = [productivity, office],
      # A list of categories/genres to which this app belongs, sorted with best fit first.
      # See the list of categories at
      # https://docs.sandstorm.io/en/latest/developing/publishing-apps/#categories

      author = (
        # Fields relating to the author of this app.

        contactEmail = "openemr-sandstorm@mbp.kg",
        # Email address to contact for any issues with this app. This includes end-user support
        # requests as well as app store administrator requests, so it is very important that this be a
        # valid address with someone paying attention to it.

        #pgpSignature = embed "path/to/pgp-signature",
        # PGP signature attesting responsibility for the app ID. This is a binary-format detached
        # signature of the following ASCII message (not including the quotes, no newlines, and
        # replacing <app-id> with the standard base-32 text format of the app's ID):
        #
        # "I am the author of the Sandstorm.io app with the following ID: <app-id>"
        #
        # You can create a signature file using `gpg` like so:
        #
        #     echo -n "I am the author of the Sandstorm.io app with the following ID: <app-id>" | gpg --sign > pgp-signature
        #
        # Further details including how to set up GPG and how to use keybase.io can be found
        # at https://docs.sandstorm.io/en/latest/developing/publishing-apps/#verify-your-identity

        upstreamAuthor = "Example App Team",
        # Name of the original primary author of this app, if it is different from the person who
        # produced the Sandstorm package. Setting this implies that the author connected to the PGP
        # signature only "packaged" the app for Sandstorm, rather than developing the app.
        # Remove this line if you consider yourself as the author of the app.
      ),

      #pgpKeyring = embed "path/to/pgp-keyring",
      # A keyring in GPG keyring format containing all public keys needed to verify PGP signatures in
      # this manifest (as of this writing, there is only one: `author.pgpSignature`).
      #
      # To generate a keyring containing just your public key, do:
      #
      #     gpg --export <key-id> > keyring
      #
      # Where `<key-id>` is a PGP key ID or email address associated with the key.

      description = (defaultText = embed "../metadata/description.md"),
      # The app's description in Github-flavored Markdown format, to be displayed e.g.
      # in an app store. Note that the Markdown is not permitted to contain HTML nor image tags (but
      # you can include a list of screenshots separately).

      shortDescription = (defaultText = "medical records"),
      # A very short (one-to-three words) description of what the app does. For example,
      # "Document editor", or "Notetaking", or "Email client". This will be displayed under the app
      # title in the grid view in the app market.

      screenshots = [
        # Screenshots to use for marketing purposes.  Examples below.
        # Sizes are given in device-independent pixels, so if you took these
        # screenshots on a Retina-style high DPI screen, divide each dimension by two.

        #(width = 746, height = 795, jpeg = embed "path/to/screenshot-1.jpeg"),
        #(width = 640, height = 480, png = embed "path/to/screenshot-2.png"),
      ],
      #changeLog = (defaultText = embed "path/to/sandstorm-specific/changelog.md"),
      # Documents the history of changes in Github-flavored markdown format (with the same restrictions
      # as govern `description`). We recommend formatting this with an H1 heading for each version
      # followed by a bullet list of changes.
    ),
  ),

  sourceMap = (
    # Here we defined where to look for files to copy into your package. The
    # `spk dev` command actually figures out what files your app needs
    # automatically by running it on a FUSE filesystem. So, the mappings
    # here are only to tell it where to find files that the app wants.
    searchPath = [
      ( sourcePath = "." ),  # Search this directory first.
      ( sourcePath = "/",    # Then search the system root directory.
        hidePaths = [ "home", "proc", "sys",
                      "etc/passwd", "etc/hosts", "etc/host.conf",
                      "etc/nsswitch.conf", "etc/resolv.conf" ]
        # You probably don't want the app pulling files from these places,
        # so we hide them. Note that /dev, /var, and /tmp are implicitly
        # hidden because Sandstorm itself provides them.
      )
    ]
  ),

  fileList = "sandstorm-files.list",
  # `spk dev` will write a list of all the files your app uses to this file.
  # You should review it later, before shipping your app.

  alwaysInclude = [
    "opt/openemr-7.0.3",
    "usr/share/mariadb/english"
  ],
  # Fill this list with more names of files or directories that should be
  # included in your package, even if not listed in sandstorm-files.list.
  # Use this to force-include stuff that you know you need but which may
  # not have been detected as a dependency during `spk dev`. If you list
  # a directory here, its entire contents will be included recursively.

  bridgeConfig = (
    # Used for integrating permissions and roles into the Sandstorm shell
    # and for sandstorm-http-bridge to pass to your app.
    # Uncomment this block and adjust the permissions and roles to make
    # sense for your app.
    # For more information, see high-level documentation at
    # https://docs.sandstorm.io/en/latest/developing/auth/
    # and advanced details in the "BridgeConfig" section of
    # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/package.capnp
    viewInfo = (
      # For details on the viewInfo field, consult "ViewInfo" in
      # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/grain.capnp

      permissions = [
      # Permissions which a user may or may not possess.  A user's current
      # permissions are passed to the app as a comma-separated list of `name`
      # fields in the X-Sandstorm-Permissions header with each request.
      #
      # IMPORTANT: only ever append to this list!  Reordering or removing fields
      # will change behavior and permissions for existing grains!  To deprecate a
      # permission, or for more information, see "PermissionDef" in
      # https://github.com/sandstorm-io/sandstorm/blob/master/src/sandstorm/grain.capnp

      #
      # Open-EMR porting note:
      #
      # Sandstorm implements a simple access control system: users have roles
      # and roles grant permissions.
      #
      # Open-EMR requires a more complex system.  Users may have multiple roles
      # and anonymous users are not supported.
      #
      # To support all of Open-EMR's functionality, we are passing roles
      # instead of permissions through X-Sandstorm-Permissions.  In the future,
      # we hope that Sandstorm will implement a more flexible system (as
      # capability-based security allows), which will allow us to better
      # support Open-EMR's needs.
      #
        (
          name = "role:administrator",
          # Name of the permission, used as an identifier for the permission in cases where string
          # names are preferred.  Used in sandstorm-http-bridge's X-Sandstorm-Permissions HTTP header.

          title = (
            defaultText = "Administrator Role",
            localizations = [
              (
                locale = "ru",
                text = "Роль администратора",
              ),
              (
                locale = "zh",
                text = "管理员角色",
              ),
              (
                locale = "zh-TW",
                text = "管理員角色",
              ),
            ],
          ),
          # Display name of the permission, e.g. to display in a checklist of permissions
          # that may be assigned when sharing.

          description = (
            defaultText = "has full control of the application",
            localizations = [
              (
                locale = "ru",
                text = "имеет полный контроль над приложением",
              ),
              (
                locale = "zh",
                text = "完全控制应用程序",
              ),
              (
                locale = "zh-TW",
                text = "完全控制應用程式",
              ),
            ],
          ),
          # Prose describing what this role means, suitable for a tool tip or similar help text.
        ),
        (
          name = "role:manager",
          title = (
            defaultText = "Manager Role",
            localizations = [
              (
                locale = "ru",
                text = "Роль менеджера",
              ),
              (
                locale = "zh",
                text = "经理角色",
              ),
              (
                locale = "zh-TW",
                text = "經理角色",
              ),
            ],
          ),
          description = (
            defaultText = "has the access to view and edit all parts of the application",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к просмотру и редактированию всех частей приложения",
              ),
              (
                locale = "zh",
                text = "有权查看和编辑应用程序的所有部分",
              ),
              (
                locale = "zh-TW",
                text = "有權查看和編輯應用程式的所有部分",
              ),
            ],
          ),
        ),
        (
          name = "role:back office",
          title = (
            defaultText = "Back Office Role",
            localizations = [
              (
                locale = "ru",
                text = "Роль бэк-офиса",
              ),
              (
                locale = "zh",
                text = "后台角色",
              ),
              (
                locale = "zh-TW",
                text = "後台角色",
              ),
            ],
          ),
          description = (
            defaultText = "has access to business and financial information",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к деловой и финансовой информации",
              ),
              (
                locale = "zh",
                text = "可以访问商业和财务信息",
              ),
              (
                locale = "zh-TW",
                text = "可以存取商業和財務信息",
              ),
            ],
          ),
        ),
        (
          name = "role:front office",
          title = (
            defaultText = "Front Office Role",
            localizations = [
              (
                locale = "ru",
                text = "Роль фронт-офиса",
              ),
              (
                locale = "zh",
                text = "前台角色",
              ),
              (
                locale = "zh-TW",
                text = "前台角色",
              ),
            ],
          ),
          description = (
            defaultText = "has access to customer and financial information and some medical records",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к информации о клиентах и финансовой информации, а также к некоторым медицинским записям",
              ),
              (
                locale = "zh",
                text = "可以访问客户和财务信息以及一些医疗记录",
              ),
              (
                locale = "zh-TW",
                text = "可以存取客戶和財務資訊以及一些醫療記錄",
              ),
            ],
          ),
        ),
        (
          name = "role:clinician",
          title = (
            defaultText = "Clinician Role",
            localizations = [
              (
                locale = "ru",
                text = "Роль клинициста",
              ),
              (
                locale = "zh",
                text = "临床医生角色",
              ),
              (
                locale = "zh-TW",
                text = "臨床醫師角色",
              ),
            ],
          ),
          description = (
            defaultText = "has access to customer information and medical records",
            localizations = [
              (
                locale = "ru",
                text = "имеет возможность доступа к информации о клиентах и медицинским записям",
              ),
              (
                locale = "zh",
                text = "能够访问客户信息和医疗记录",
              ),
              (
                locale = "zh-TW",
                text = "能夠存取客戶資訊和醫療記錄",
              ),
            ],
          ),
        ),
      ],
      roles = [
        # Roles are logical collections of permissions.  For instance, your app may have
        # a "viewer" role and an "editor" role
        (
          title = (
            defaultText = "Administrator",
            localizations = [
              (
                locale = "ru",
                text = "Администратор",
              ),
              (
                locale = "zh",
                text = "管理员",
              ),
              (
                locale = "zh-TW",
                text = "管理員",
              ),
            ],
          ),
          # Name of the role.  Shown in the Sandstorm UI to indicate which users have which roles.

          permissions  = [
            true,  # role:administrator
            false, # role:manager
            false, # role:back office
            false, # role:front office
            false, # role:clinician
          ],
          # An array indicating which permissions this role carries.
          # It should be the same length as the permissions array in
          # viewInfo, and the order of the lists must match.

          verbPhrase = (
            defaultText = "has full control of the application",
            localizations = [
              (
                locale = "ru",
                text = "имеет полный контроль над приложением",
              ),
              (
                locale = "zh",
                text = "完全控制应用程序",
              ),
              (
                locale = "zh-TW",
                text = "完全控制應用程式",
              ),
            ],
          ),
          # Brief explanatory text to show in the sharing UI indicating
          # what a user assigned this role will be able to do with the grain.

          description = (defaultText = "editors may view all site data and change settings."),
          # Prose describing what this role means, suitable for a tool tip or similar help text.
        ),
        (
          title = (
            defaultText = "Manager",
            localizations = [
              (
                locale = "ru",
                text = "Менеджер",
              ),
              (
                locale = "zh",
                text = "经理",
              ),
              (
                locale = "zh-TW",
                text = "經理",
              ),
            ],
          ),
          permissions  = [
            false, # role:administrator
            true,  # role:manager
            false, # role:back office
            false, # role:front office
            false, # role:clinician
          ],
          verbPhrase = (
            defaultText = "has the access to view and edit all parts of the application",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к просмотру и редактированию всех частей приложения",
              ),
              (
                locale = "zh",
                text = "有权查看和编辑应用程序的所有部分",
              ),
              (
                locale = "zh-TW",
                text = "有權查看和編輯應用程式的所有部分",
              ),
            ],
          ),
        ),
        (
          title = (
            defaultText = "Back Office",
            localizations = [
              (
                locale = "ru",
                text = "Бэк-офис",
              ),
              (
                locale = "zh",
                text = "后台",
              ),
              (
                locale = "zh-TW",
                text = "後台",
              ),
            ],
          ),
          permissions  = [
            false, # role:administrator
            false, # role:manager
            true,  # role:back office
            false, # role:front office
            false, # role:clinician
          ],
          verbPhrase = (
            defaultText = "has access to business and financial information",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к деловой и финансовой информации",
              ),
              (
                locale = "zh",
                text = "可以访问商业和财务信息",
              ),
              (
                locale = "zh-TW",
                text = "可以存取商業和財務信息",
              ),
            ],
          ),
        ),
        (
          title = (
            defaultText = "Front Office",
            localizations = [
              (
                locale = "ru",
                text = "фронт-офис",
              ),
              (
                locale = "zh",
                text = "前台",
              ),
              (
                locale = "zh-TW",
                text = "前台",
              ),
            ],
          ),
          permissions  = [
            false, # role:administrator
            false, # role:manager
            false, # role:back office
            true,  # role:front office
            false, # role:clinician
          ],
          verbPhrase= (
            defaultText = "has access to customer and financial information and some medical records",
            localizations = [
              (
                locale = "ru",
                text = "имеет доступ к информации о клиентах и финансовой информации, а также к некоторым медицинским записям",
              ),
              (
                locale = "zh",
                text = "可以访问客户和财务信息以及一些医疗记录",
              ),
              (
                locale = "zh-TW",
                text = "可以存取客戶和財務資訊以及一些醫療記錄",
              ),
            ],
          ),
        ),
        (
          title = (
            defaultText = "Clinician",
            localizations = [
              (
                locale = "ru",
                text = "Клиницист",
              ),
              (
                locale = "zh",
                text = "临床医生",
              ),
              (
                locale = "zh-TW",
                text = "臨床醫師",
              ),
            ],
          ),
          permissions  = [
            false, # role:administrator
            false, # role:manager
            false, # role:back office
            false, # role:front office
            true,  # role:clinician
          ],
          verbPhrase = (
            defaultText = "has access to customer information and medical records",
            localizations = [
              (
                locale = "ru",
                text = "имеет возможность доступа к информации о клиентах и медицинским записям",
              ),
              (
                locale = "zh",
                text = "能够访问客户信息和医疗记录",
              ),
              (
                locale = "zh-TW",
                text = "能夠存取客戶資訊和醫療記錄",
              ),
            ],
          ),
        ),
      ],
    ),
    #apiPath = "/api",
    # Apps can export an API to the world.  The API is to be used primarily by Javascript
    # code and native apps, so it can't serve out regular HTML to browsers.  If a request
    # comes in to your app's API, sandstorm-http-bridge will prefix the request's path with
    # this string, if specified.
  ),
);

const myCommand :Spk.Manifest.Command = (
  # Here we define the command used to start up your server.
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/.sandstorm/launcher.sh"],
  environ = [
    # Note that this defines the *entire* environment seen by your app.
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "SANDSTORM", value = "1"),
    # Export SANDSTORM=1 into the environment, so that apps running within Sandstorm
    # can detect if $SANDSTORM="1" at runtime, switching UI and/or backend to use
    # the app's Sandstorm-specific integration code.
  ]
);
