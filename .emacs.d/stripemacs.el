;; NOTE: This file is generated - it's recommended that you edit the stripemacs.org
;;       file and then regenerate the code with <C-c C-v t>
;; Setup

(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(setq use-package-always-ensure t)


;; Ruby and YAML

(use-package ruby-mode
  :config
  (defun my-ruby-mode-hook ()
    (set-fill-column 80)
    (add-hook 'before-save-hook 'delete-trailing-whitespace nil 'local)
    (setq ruby-insert-encoding-magic-comment nil))
  (add-hook 'ruby-mode-hook 'my-ruby-mode-hook))

(use-package yaml-mode)

;; Frontend
(use-package web-mode
  :init
  (defun web-mode-customization ()
    "Customization for web-mode."
    (setq web-mode-markup-indent-offset 2)
    (setq web-mode-attr-indent-offset 2)
    (setq web-mode-css-indent-offset 2)
    (setq web-mode-code-indent-offset 2)
    (setq web-mode-enable-auto-pairing t)
    (setq web-mode-enable-css-colorization t)
    (add-hook 'before-save-hook 'delete-trailing-whitespace nil 'local))
  (add-hook 'web-mode-hook 'web-mode-customization)

  :mode ("\\.html?\\'" "\\.erb\\'" "\\.hbs\\'"
         "\\.jsx?\\'" "\\.json\\'" "\\.s?css\\'"
         "\\.less\\'" "\\.sass\\'"))
(defun get-eslint-executable ()
  (let ((root (locate-dominating-file
                (or (buffer-file-name) default-directory)
                "package.json")))
    (and root
         (expand-file-name "node_modules/eslint/bin/eslint.js"
                           root))))

(defun my/use-eslint-from-node-modules ()
  (let ((eslint (get-eslint-executable)))
    (when (and eslint (file-executable-p eslint))
      (setq flycheck-javascript-eslint-executable eslint))))
(use-package company-flow
  :config
  (add-to-list 'company-backends 'company-flow))

(defun get-flow-executable ()
  (let ((root (locate-dominating-file
                (or (buffer-file-name) default-directory)
                "package.json")))
    (and root
         (expand-file-name "node_modules/flow-bin/cli.js"
                           root))))

(defun my/use-flow-from-node-modules ()
  (let ((flow (get-flow-executable)))
    (when (and flow (file-exists-p flow))
      (setq flycheck-javascript-flow-executable flow))))
(use-package flycheck-flow)
(defun enable-minor-mode (my-pair)
  (if (buffer-file-name)
    (if (string-match (car my-pair) buffer-file-name)
      (funcall (cdr my-pair)))))

(use-package prettier-js
  :init
  (add-hook 'web-mode-hook #'(lambda () (enable-minor-mode '("\\.jsx?\\'" . prettier-js-mode)))))

;; Tools
(use-package company
  :config (global-company-mode))
(use-package projectile
  :init
  (setq projectile-indexing-method 'alien)
  (setq projectile-use-git-grep t)
  (setq projectile-tags-command "/usr/local/bin/ctags --exclude=node_modules --exclude=admin --exclude=.git --exclude=frontend --exclude=home --exclude=**/*.js -Re -f \"%s\" %s")

  :config
  (projectile-global-mode))
(use-package flycheck
  :init
  (setq flycheck-ruby-rubocop-executable "~/stripe/pay-server/scripts/bin/rubocop")
  (setq flycheck-ruby-executable (format "/Users/%s/.rbenv/shims/ruby" stripe-username))

  :config
  (setq-default flycheck-disabled-checkers
                (append flycheck-disabled-checkers
                        '(javascript-jshint)
                        '(ruby-rubylint)
                        '(json-jsonlist)
                        '(emacs-lisp-checkdoc)))

  (add-hook 'flycheck-mode-hook #'my/use-eslint-from-node-modules)
  (add-hook 'flycheck-mode-hook #'my/use-flow-from-node-modules)

  ;; use eslint and flow with web-mode for jsx files
  (flycheck-add-mode 'javascript-eslint 'web-mode)
  (flycheck-add-mode 'javascript-flow 'web-mode)
  (flycheck-add-next-checker 'javascript-flow '(t . javascript-eslint))
  (global-flycheck-mode))

;; Functions
(defun insert-jira (project jiranum)
  (interactive (concat "M" project "-"))
  (insert (format "https://jira.corp.stripe.com/browse/ATLASENG-%s"
                  jiranum)))
(defun open-pr ()
  (interactive)
  (let ((current-branch (magit-get-current-branch))
        (remote-url "git@git.corp.stripe.com:stripe-internal/pay-server"))
    (browse-url (remote-url-to-github-pr remote-url current-branch))))

(defun remote-url-to-github-pr (remote-url current-branch)
  (let ((suffix (nth 1 (split-string remote-url ":"))))
    (format "https://git.corp.stripe.com/%s/compare/%s?expand=1" suffix current-branch)))
(defun run-payserver-test-line ()
  (interactive)
  (let ((cur-line (+ 1 (count-lines (point-min) (point)))))
    (run-payserver-tests cur-line)))

(defun pay-test-line () (run-payserver-test-line))

(defun run-payserver-test-file ()
  (interactive)
  (run-payserver-tests nil))

(defun pay-test-file () (interactive) (run-payserver-test-file))

(defun run-payserver-tests (cur-line)
  (run-payserver-command-in-buffer "*payserver-tests*"
   (build-test-args (buffer-file-name) cur-line)))

(defun build-test-args (full-filename line)
  (let* ((filename (replace-regexp-in-string "^.*pay-server/" "" full-filename))
         (file-line-args (if line
                             (list "-l" (number-to-string line))
                           (list))))
    (append (list "/usr/local/bin/pay" "test" filename) file-line-args)))
(defun view-payserver-test-log ()
  (interactive)
  (let ((default-directory (build-payserver-command-url))
        (log-file (replace-regexp-in-string "See \\(.*\\) for details." "\\1" (thing-at-point 'line t))))
    (find-file (format "/ssh:%s:%s" devbox-machine log-file))))
(defun build-payserver-command-url (&optional subdirectory)
  (format "~/stripe/pay-server%s" (if subdirectory subdirectory "")))

(defun run-payserver-command-in-buffer (buffer-name command-args)
  (let ((default-directory (build-payserver-command-url))
        (cur-buffer (current-buffer)))
    (progn
      (other-window 1)
      (switch-to-buffer buffer-name)
      (set-buffer (get-buffer buffer-name))
      (erase-buffer) ; Clear out test buffer before running
      (goto-char (point-min))
      (insert (concat (mapconcat 'identity command-args " ") "\n"))
      (set-buffer cur-buffer)
      (apply 'start-file-process buffer-name (get-buffer buffer-name) command-args))))

(defun run-payserver-command (command-args)
  (let ((default-directory (build-payserver-command-url)))
    (shell-command-to-string (join " " command-args))))

(defun join (sep lst)
  (mapconcat 'identity lst sep))

(global-set-key [f6] 'run-payserver-test-line)
(global-set-key [f5] 'run-payserver-test-file)
