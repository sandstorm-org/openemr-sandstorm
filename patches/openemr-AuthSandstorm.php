--- /dev/null	2025-10-20 04:26:31.631999972 +0000
+++ /opt/openemr-7.0.3/openemr/src/Common/Auth/AuthSandstorm.php	2025-10-20 10:55:25.457835830 +0000
@@ -0,0 +1,184 @@
+<?php
+
+/**
+ * AuthSandstorm class.
+ *
+ *   Support for Sandstorm's authentication model
+ *
+ * @package   Open-EMR for Sandstorm
+ * @link      https://github.com/sandstorm-org/openemr-sandstorm
+ * @author    Marcus Yu <saguiau4417@gmail.com>
+ * @author    Troy J. Farrell <troy@entheossoft.com>
+ * @copyright Copyright (c) 2025 Marcus Yu, Troy J. Farrell
+ * @license   https://github.com/openemr/openemr/blob/master/LICENSE GNU General Public License 3
+ */
+
+namespace OpenEMR\Common\Auth;
+
+class AuthSandstorm
+{
+    /**
+     * @var string
+     */
+    private $displayName;
+    /**
+     * @var string[]
+     */
+    private $permissions;
+    /**
+     * @var string
+     */
+    private $pictureUrl;
+    /**
+     * @var string
+     */
+    private $preferredHandle;
+    /**
+     * @var string
+     */
+    private $pronouns;
+    /**
+     * @var string
+     */
+    private $sessionType;
+    /**
+     * @var string
+     */
+    private $sessionId;
+    /**
+     * @var string
+     */
+    private $tabId;
+    /**
+     * @var string
+     */
+    private $userId;
+
+
+    public function __construct() {
+        $this->populateWithHeaders();
+    }
+
+    /**
+     * Die if the user is anonymous
+     *
+     * @param string $message
+     */
+    public function dieIfAnonymous($message = '') {
+        if (empty($this->userId)) {
+            if (empty($message)) {
+                $message = '<div style="display: flex;justify-content: center;height: 100%;"><div style="display: flex;justify-content: center;width: 50%;height: 100%;align-items: center;background-color: #f8f9fa;"><p style="font-size: 1.25rem; font-family: Segoe UI,Roboto;">Please Log In with Sandstorm to use Open-EMR</p></div></div>';
+            }
+            die($message);
+        }
+    }
+
+    /**
+     * Return the user's display name as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getDisplayName() {
+        return $this->displayName;
+    }
+
+    /**
+     * Return the user's permissions as received from Sandstorm
+     *
+     * @return string[]
+     */
+    public function getPermissions() {
+        return $this->displayName;
+    }
+
+    /**
+     * Return the URL of the user's picture as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getPictureUrl() {
+        return $this->pictureUrl;
+    }
+
+    /**
+     * Return the user's preferred handle as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getPreferredHandle() {
+        return $this->preferredHandle;
+    }
+
+    /**
+     * Return the user's pronouns as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getPronouns() {
+        return $this->pronouns;
+    }
+
+    /**
+     * Return the session type as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getSessionType() {
+        return $this->sessionType;
+    }
+
+    /**
+     * Return the session ID as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getSessionId() {
+        return $this->sessionId;
+    }
+
+    /**
+     * Return the tab ID as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getTabId() {
+        return $this->tabId;
+    }
+
+    /**
+     * Return the user ID as received from Sandstorm
+     *
+     * @return string
+     */
+    public function getUserId() {
+        return $this->userId;
+    }
+
+    private function populateWithHeaders() {
+        $headers = getallheaders();
+
+        // displayName
+        $displayNameEncoded = $headers['X-Sandstorm-Username'];
+        if (!empty($displayNameEncoded)) {
+            $this->displayName = urldecode($displayNameEncoded);
+        } else {
+            $this->displayName = '';
+        }
+
+        // permissions
+        $permissionsString = $headers['X-Sandstorm-Permissions'];
+        if (!empty($permissionsString)) {
+            $this->permissions = explode(',', $permissionsString);
+        } else {
+            $this->permissions = array(); 
+        }
+
+        $this->pictureUrl = $headers['X-Sandstorm-User-Picture'];
+        $this->preferredHandle = $headers['X-Sandstorm-Preferred-Handle'];
+        $this->pronouns = $headers['X-Sandstorm-User-Pronouns'];
+        $this->sessionType = $headers['X-Sandstorm-Session-Type'];
+        $this->sessionId = $headers['X-Sandstorm-Session-Id'];
+        $this->tabId = $headers['X-Sandstorm-Tab-Id'];
+        $this->userId = $headers['X-Sandstorm-User-Id'];
+    }
+}
