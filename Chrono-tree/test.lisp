(cl:in-package #:chrono-tree-test)

(defvar *time*)

(defclass container ()
  ((%contents :initform nil :accessor contents)))

(defun node-count (container)
  (if (null (contents container))
      0
      (chrono-tree:node-count (contents container))))

(defclass node (chrono-tree:node)
  ((%container :initarg :container :reader container)
   (%item :initarg :item :accessor item))
  (:default-initargs :create-time (incf *time*)))

(defun find-node (node-number tree)
  (let* ((left (splay-tree:left tree))
	 (left-count (if (null left) 0 (chrono-tree:node-count left))))
    (cond ((< node-number left-count)
	   (find-node node-number left))
	  ((= node-number left-count)
	   tree)
	  (t
	   (find-node (- node-number (1+ left-count)) (splay-tree:right tree))))))

(defun splay (node)
  (setf (contents (container node))
	(splay-tree:splay node)))

(defun insert-item (item container position)
  ;; An intrinsic restriction of chrono trees.
  (assert (<= 1 position (node-count container)))
  (let ((new-node (make-instance 'node :container container :item item))
	(prev (splay (find-node (1- position) (contents container)))))
    (setf (chrono-tree:modify-time prev) (incf *time*))
    (if (null (splay-tree:right prev))
	(progn (setf (splay-tree:left new-node) prev)
	       (setf (contents container) new-node))
	(let ((next (splay (find-node position (contents container)))))
	  (setf (splay-tree:left next) nil)
	  (setf (splay-tree:left new-node) prev)
	  (setf (splay-tree:right new-node) next)
	  (setf (contents container) new-node)))))

(defun delete-node (container position)
  ;; An intrinsic restriction of chrono trees.
  (assert (<= 1 position (1- (node-count container))))
  (let* ((node (splay (find-node position (contents container))))
	 (prev (splay (find-node (1- position) (contents container))))
	 (next (splay-tree:right node)))
    (setf (chrono-tree:modify-time prev) (incf *time*))
    (setf (splay-tree:right prev) nil)
    (setf (splay-tree:right node) nil)
    (setf (splay-tree:right prev) next)))

(defun modify-node (container position new-item)
  (assert (<= 0 position (1- (node-count container))))
  (let ((node (splay (find-node position (contents container)))))
    (setf (chrono-tree:modify-time node) (incf *time*))
    (setf (car (item node)) new-item)))

(defun tree-to-sequence (tree)
  (let ((result '()))
    (labels ((traverse (node)
	       (if (null node)
		   nil
		   (progn (traverse (splay-tree:right node))
			  (push (item node) result)
			  (traverse (splay-tree:left node))))))
      (traverse tree))
    result))

(defvar *container*)

(defun one-operation ()
  (if (= (node-count *container*) 1)
      ;; There is a single item in the container
      (ecase (random 2)
	(0
	 (modify-node *container* 0 (random 1000000)))
	(1
	 (insert-item (list (random 1000000)) *container* 1)))
      ;; There are at lest two items.
      (ecase (random 4)
	(0
	 (let ((position (random (node-count *container*))))
	   (modify-node *container* position (random 1000000))))
	((1 2)
	 (let ((position (1+ (random (node-count *container*)))))
	   (insert-item (list (random 1000000)) *container* position)))
	(3
	 (let ((position (1+ (random (1- (node-count *container*))))))
	   (delete-node *container* position))))))

(defun compare-containers (container list)
  (every (lambda (a b)
	   (and (eq a (car b))
		(eql (caar b) (cadr b))))
	 (tree-to-sequence (contents container))
	 list))

(defun test ()
  (let* ((item (list (random 1000000)))
	 (list (list nil))
	 (list-time 0)
	 (*container* (make-instance 'container))
	 (*time* 0)
	 (length 0))
    (setf (contents *container*)
	  (make-instance 'node
	    :container *container*
	    :item item))
    (flet ((synchronize ()
	     ;; (format t "~%")
	     ;; (format t "***tree: ~d~%" (tree-to-sequence (contents *container*)))
	     ;; (format t "***list before: ~d~%" (cdr list))
	     (let ((rest list))
	       (flet ((skip (n)
			;; (format t "skipping ~d~%" n)
			(setf rest (nthcdr n rest)))
		      (modify (node)
			(loop until (eq (car (cadr rest))
					(item node))
			      do (assert (not (null (cdr rest))))
				 (pop (cdr rest)))
			(setf (cadr (cadr rest))
			      (caar (cadr rest)))
			;; (format t "modifying ~s~%" (cadr rest))
			(pop rest))
		      (sync (node)
			(loop until (eq (car (cadr rest))
					(item node))
			      do (assert (not (null (cdr rest))))
				 (pop (cdr rest)))
			;; (format t "synchronizing ~s~%" (cadr rest))
			(pop rest))
		      (create (node)
			(push (list (item node) (car (item node)))
			      (cdr rest))
			;; (format t "creating ~s~%" (cadr rest))
			(pop rest)))
		 (chrono-tree:synchronize (contents *container*)
					  list-time
					  #'sync #'skip #'modify #'create)))
	     ;; (format t "***list after: ~d~%" (cdr list))
	     ))
      (loop repeat 10000
	  do (loop repeat 20
		   do (one-operation)
		      (setf length (max length (node-count *container*))))
	     (synchronize)
	     (setf list-time *time*)
	     (assert (compare-containers *container* (cdr list)))))
    length))
    
