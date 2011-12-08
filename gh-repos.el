;;; gh-repos.el --- repos module for gh.el

;; Copyright (C) 2011  Free Software Foundation, Inc.

;; Author: Yann Hodique <yann.hodique@gmail.com>
;; Keywords:

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;

;;; Code:

(eval-when-compile
  (require 'cl))

(require 'eieio)
(require 'gh-api)
(require 'gh-auth)
(require 'gh-common)

;;;###autoload
(defclass gh-repos-api (gh-api-v3)
  ((repo-cls :allocation :class :initform gh-repos-repo))
  "Repos API")

;;;###autoload
(defclass gh-repos-repo-stub (gh-object)
  ((name :initarg :name)
   (description :initarg :description :initform nil)
   (homepage :initarg :homepage :initform nil)
   (private :initarg :private :initform nil))
  "Class for user-created repository objects")

(defmethod gh-object-read-into ((stub gh-repos-repo-stub) data)
  (call-next-method)
  (with-slots (name description homepage private)
      stub
    (setq name (gh-read data 'name)
          description (gh-read data 'description)
          homepage (gh-read data 'homepage)
          private (gh-read data 'private))))

;;;###autoload
(defclass gh-repos-repo (gh-repos-repo-stub)
  ((url :initarg :url)
   (html-url :initarg :html-url)
   (clone-url :initarg :clone-url)
   (git-url :initarg :git-url)
   (ssh-url :initarg :ssh-url)
   (svn-url :initarg :svn-url)
   (owner :initarg :owner :initform nil)
   (language :initarg :language)
   (fork :initarg :fork)
   (forks :initarg :forks)
   (watchers :initarg :watchers)
   (size :initarg :size)
   (open-issues :initarg :open-issues)
   (pushed-at :initarg :pushed-at)
   (created-at :initarg :created-at)

   (owner-cls :allocation :class :initform gh-user))
  "Class for GitHub repositories")

(defmethod gh-object-read-into ((repo gh-repos-repo) data)
  (call-next-method)
  (with-slots (url html-url clone-url git-url ssh-url svn-url
                   owner language fork forks watchers size open-issues
                   pushed-at created-at)
      repo
    (setq url (gh-read data 'url)
          html-url (gh-read data 'html_url)
          clone-url (gh-read data 'clone_url)
          git-url (gh-read data 'git_url)
          ssh-url (gh-read data 'ssh_url)
          svn-url (gh-read data 'svn_url)
          owner (gh-object-read (or (oref repo :owner)
                                    (oref repo owner-cls))
                                (gh-read data 'owner))
          language (gh-read data 'language)
          fork (gh-read data 'fork)
          forks (gh-read data 'forks)
          watchers (gh-read data 'watchers)
          size (gh-read data 'size)
          open-issues (gh-read data 'open_issues)
          pushed-at (gh-read data 'pushed_at)
          created-at (gh-read data 'created_at))))

(defclass gh-repos-ref (gh-object)
  ((label :initarg :label)
   (ref :initarg :ref :initform nil)
   (sha :initarg :sha :initform nil)
   (user :initarg :user :initform nil)
   (repo :initarg :repo :initform nil)

   (user-cls :allocation :class :initform gh-user)
   (repo-cls :allocation :class :initform gh-repos-repo)))

(defmethod gh-object-read-into ((r gh-repos-ref) data)
  (call-next-method)
  (with-slots (label ref sha user repo)
      r
    (setq label (gh-read data 'label)
          ref (gh-read data 'ref)
          sha (gh-read data 'sha)
          user (gh-object-read (or (oref r :user)
                                    (oref r user-cls))
                                (gh-read data 'user))
          repo (gh-object-read (or (oref r :repo)
                                   (oref r repo-cls))
                               (gh-read data 'repo)))))

(defmethod gh-repos-user-list ((api gh-repos-api) &optional username)
  (gh-api-authenticated-request
   api (gh-object-list-reader (oref api repo-cls)) "GET"
   (format "/users/%s/repos" (or username (gh-api-get-username api)))))

(defmethod gh-repos-org-list ((api gh-repos-api) org)
  (gh-api-authenticated-request
   api (gh-object-list-reader (oref api repo-cls))
   (format "/orgs/%s/repos" org)))

(defmethod gh-repos-repo-to-obj ((repo gh-repos-repo-stub)
                                 &rest caps)
  (let ((has_issues (plist-member caps :issues))
        (has_wiki (plist-member caps :wiki))
        (has_downloads (plist-member caps :downloads)))
    `(("name" . ,(oref repo :name))
      ("homepage" . ,(oref repo :homepage))
      ("description" . ,(oref repo :description))
      ("public" . ,(not (oref repo :private)))
      ,@(when has_issues
          (list (cons "has_issues" (plist-get caps :issues))))
      ,@(when has_wiki
          (list (cons "has_wiki" (plist-get caps :wiki))))
      ,@(when has_downloads
          (list (cons "has_downloads" (plist-get caps :downloads)))))))

(defmethod gh-repos-repo-new ((api gh-repos-api) repo-stub
                              &optional org &rest caps)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api repo-cls)) "POST"
   (if org (format "/orgs/%s/repos" org)
     "/user/repos")
   (apply 'gh-repos-repo-to-obj repo-stub caps)))

(defmethod gh-repos-repo-get ((api gh-repos-api) repo-id &optional user)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api repo-cls)) "GET"
   (format "/repos/%s/%s"
           (or user (gh-api-get-username api))
           repo-id)))

(defmethod gh-repos-repo-update ((api gh-repos-api) repo-stub
                                 &optional user &rest caps)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api repo-cls)) "PATCH"
   (format "/repos/%s/%s"
           (or user (gh-api-get-username api))
           (oref repo-stub :name))
   (apply 'gh-repos-repo-to-obj repo-stub caps)))

(defmethod gh-repos-repo-contributors ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api repo-cls)) "GET"
   (format "/repos/%s/%s/contributors"
           (oref (oref repo :owner) :login)
           (oref repo :name))))

;;; TODO: generate some useful objects with the return values

(defmethod gh-repos-repo-languages ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api nil "GET" (format "/repos/%s/%s/languages"
                         (oref (oref repo :owner) :login)
                         (oref repo :name))))

(defmethod gh-repos-repo-teams ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api nil "GET" (format "/repos/%s/%s/teams"
                         (oref (oref repo :owner) :login)
                         (oref repo :name))))

(defmethod gh-repos-repo-tags ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api nil "GET" (format "/repos/%s/%s/tags"
                         (oref (oref repo :owner) :login)
                         (oref repo :name))))

(defmethod gh-repos-repo-branches ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api nil "GET" (format "/repos/%s/%s/branches"
                         (oref (oref repo :owner) :login)
                         (oref repo :name))))

;;; Forks sub-API

(defmethod gh-repos-forks-list ((api gh-repos-api) repo)
  (gh-api-authenticated-request
   api (gh-object-list-reader (oref api repo-cls)) "GET"
   (format "/repos/%s/%s/forks"
           (oref (oref repo :owner) :login)
           (oref repo :name))))

(defmethod gh-repos-fork ((api gh-repos-api) repo &optional org)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api repo-cls)) "POST"
   (format "/repos/%s/%s/forks"
           (oref (oref repo :owner) :login)
           (oref repo :name))
   nil (when org `(("org" . ,org)))))

(provide 'gh-repos)
;;; gh-repos.el ends here
