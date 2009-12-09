;;;
;;; Copyright (C) 2009 Keith James. All rights reserved.
;;;
;;; This file is part of cl-sam.
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;

(in-package :sam)

(defconstant +tag-size+ 2
  "The size of a BAM auxilliary tag in bytes.")

(deftype bam-alignment ()
  '(simple-array (unsigned-byte 8) (*)))

(defgeneric encode-alignment-tag (value tag vector index)
  (:documentation "Performs binary encoding of VALUE into VECTOR under
  TAG at INDEX, returning VECTOR."))

(defgeneric alignment-tag-documentation (tag)
  (:documentation "Returns the documentation for TAG or NIL if none is
  available."))

(defmethod encode-alignment-tag (value tag vector index)
  (declare (ignore value vector index))
  (error "Unknown tag ~a." tag))

(defmethod alignment-tag-documentation (tag)
  (error "Unknown tag ~a." tag))

(defmacro define-alignment-tag (tag value-type &optional docstring)
  "Defines a new alignment tag to hold a datum of a particular SAM
type.

Arguments:

- tag (symbol): The tag e.g. :rg
- value-type (symbol): The value type, one of :char , :string , :hex
:int32 or :float .

Optional:

- docstring (string): Documentation for the tag."
  (let ((encode-fn (ecase value-type
                     (:char 'encode-char-tag)
                     (:string 'encode-string-tag)
                     (:hex 'encode-hex-tag)
                     (:int32 'encode-int-tag)
                     (:float 'encode-float-tag)))
        (prefix (make-array 2 :element-type '(unsigned-byte 8)
                            :initial-contents (loop
                                                 for c across (symbol-name tag)
                                                 collect (char-code c)))))
    `(progn
       (defmethod encode-alignment-tag (value (tag (eql ,tag))
                                        alignment-record index)
         (let ((i (+ +tag-size+ index)))
           (,encode-fn
            value (replace alignment-record ,prefix :start1 index) i)))
       (defmethod alignment-tag-documentation ((tag (eql ,tag)))
         (declare (ignore tag))
         ,docstring))))

(define-alignment-tag :rg :string
  (txt "Read group. Value matches the header RG-ID tag if @RG is present"
       "in the header."))
(define-alignment-tag :lb :string
  (txt "Library. Value should be consistent with the header RG-LB tag if"
       "@RG is present."))
(define-alignment-tag :pu :string
  (txt "Platform unit. Value should be consistent with the header RG-PU"
       "tag if @RG is present."))
(define-alignment-tag :pg :string
  (txt "Program that generates the alignment; match the header PG-ID tag"
       "if @PG is present."))
(define-alignment-tag :as :int32
  "Alignment score generated by aligner.")
(define-alignment-tag :sq :string
  "Encoded base probabilities for the suboptimal bases at each position.")
(define-alignment-tag :mq :int32
  "The mapping quality score the mate alignment.")
(define-alignment-tag :nm :int32
  "Number of nucleotide differences.")
(define-alignment-tag :h0 :int32
  "Number of perfect hits.")
(define-alignment-tag :h1 :int32
  "Number of 1-difference hits (an in/del counted as a difference).")
(define-alignment-tag :h2 :int32
  "Number of 2-difference hits (an in/del counted as a difference).")
(define-alignment-tag :uq :int32
  (txt "Phred likelihood of the read sequence, conditional on the mapping"
       "location being correct."))
(define-alignment-tag :pq :int32
  (txt "Phred likelihood of the read pair, conditional on both the mapping"
       "locations being correct."))
(define-alignment-tag :nh :int32
  (txt "Number of reported alignments that contains the query in the"
       "current record."))
(define-alignment-tag :ih :int32
  (txt "Number of stored alignments in SAM that contains the query in the"
       "current record."))
(define-alignment-tag :hi :int32
  (txt "Query hit index, indicating the alignment record is the i-th one"
       "stored in SAM."))
(define-alignment-tag :md :string
  (txt "String for mismatching positions in the format of "
       "[0-9]+(([ACGTN]|\^[ACGTN]+)[0-9]+)*"))
(define-alignment-tag :cs :string
  "Color read sequence on the same strand as the reference.")
(define-alignment-tag :cq :string
  (txt "Color read quality on the same strand as the reference, encoded"
       "in the same way as the QUAL field."))
(define-alignment-tag :cm :int32
  "Number of color differences.")
(define-alignment-tag :gs :string
  "Sequence in the overlap.")
(define-alignment-tag :gq :string
  "Quality in the overlap, encoded in the same way as the QUAL field.")
(define-alignment-tag :gc :string
  "CIGAR-like string describing the overlaps in the format of [0-9]+[SG].")
(define-alignment-tag :r2 :string
  "Sequence of the mate.")
(define-alignment-tag :q2 :string
  "Phred quality for the mate, encoded is the same as the QUAL field.")
(define-alignment-tag :s2 :string
  (txt "Encoded base probabilities for the other 3 bases for the"
       "mate-pair read, encoded in the same way as the SQ field."))
(define-alignment-tag :cc :string
  "Reference name of the next hit, \"=\" for the same chromosome.")
(define-alignment-tag :cp :int32
  "Leftmost coordinate of the next hit.")
(define-alignment-tag :sm :int32
  (txt "Mapping quality if the read is mapped as a single read rather"
       "than as a read pair."))
(define-alignment-tag :am :int32
  "Smaller single-end mapping quality of the two reads in a pair.")
(define-alignment-tag :mf :int32
  "MAQ pair flag (MAQ specific).")

;;; Various user tag extensions
(define-alignment-tag :x0 :int32)
(define-alignment-tag :x1 :int32)
(define-alignment-tag :xg :int32)
(define-alignment-tag :xm :int32)
(define-alignment-tag :xO :int32)
(define-alignment-tag :xt :char)

(defun make-reference-table (ref-meta-list)
  "Returns a hash-table mapping reference identifiers to reference
names for the reference data in REF-META-LIST."
  (let ((ref-table (make-hash-table :size (length ref-meta-list))))
    (dolist (ref-meta ref-meta-list ref-table)
      (setf (gethash (first ref-meta) ref-table) (second ref-meta)))))

(defun make-alignment-record (read-name seq-str alignment-flag
                              &key (reference-id -1) alignment-pos
                              (mate-reference-id -1) mate-alignment-pos
                              (mapping-quality 0) (alignment-bin 0)
                              (insert-length 0)
                              cigar quality-str tag-values)
  "Returns a new alignment record array.

Arguments:

- read-name (string): The read name.
- seq-str (string): The read sequence.
- alignment-flag (integer): The binary alignment flag.

Key:

- reference-id (integer): The reference identifier, defaults to -1
- alignment-pos (integer): The 1-based alignment position, defaults to -1.
- mate-reference-id (integer): The reference identifier of the mate,
  defaults to -1.
- mate-alignment-pos (integer): The 1-based alignment position of the mate.
- mapping-quality (integer): The mapping quality, defaults to 0.
- alignment-bin (integer): The alignment bin, defaults to 0.
- insert-length (integer): The insert size, defaults to 0.
- cigar (alist): The cigar represented as an alist of operations e.g.

;;; '((:M . 9) (:I . 1) (:M . 25))

- quality-str (string): The read quality string.
- tag-values (alist): The alignment tags represented as an alist e.g.

;;; '((:XT . #\U) (:NM . 1) (:X0 . 1) (:X1 . 0)
;;;   (:XM . 1) (:XO . 0) (:XG . 0) (:MD . \"3T31\"))

The tags must have been defined with {defmacro define-alignment-tag} .

Returns:

- A vector of '(unsigned-byte 8)."
  (when (and quality-str (/= (length seq-str) (length quality-str)))
    (error 'invalid-argument-error
           :params '(seq-str quality-str)
           :args (list seq-str quality-str)
           :text "read sequence and quality strings were not the same length"))
  (let* ((i 32)
         (j (+ i (1+ (length read-name))))
         (k (+ j (if (null cigar)
                     4
                   (* 4 (length cigar)))))
         (m (+ k (ceiling (length seq-str) 2)))
         (n (+ m (if (null quality-str)
                     1
                   (length quality-str))))
         (sizes (loop
                   for (nil . value) in tag-values
                   collect (alignment-tag-bytes value)))
         (alignment-record (make-array (+ n (apply #'+ sizes))
                                       :element-type '(unsigned-byte 8))))
    (encode-int32le reference-id alignment-record 0)
    (encode-int32le (or alignment-pos -1) alignment-record 4)
    (encode-int8le (1+ (length read-name)) alignment-record 8)
    (encode-int8le mapping-quality alignment-record 9)
    (encode-int16le alignment-bin alignment-record 10)
    (encode-int16le (length cigar) alignment-record 12)
    (encode-int16le alignment-flag alignment-record 14)
    (encode-int16le (length seq-str) alignment-record 16)
    (encode-int32le mate-reference-id alignment-record 20)
    (encode-int32le (or mate-alignment-pos -1) alignment-record 24)
    (encode-int32le insert-length alignment-record 28)
    (encode-read-name read-name alignment-record i)
    (encode-cigar cigar alignment-record j)
    (encode-seq-string seq-str alignment-record k)
    (encode-quality-string quality-str alignment-record m)
    (loop
       for (tag . value) in tag-values
       for size in sizes
       with offset = n
       do (progn
            (encode-alignment-tag value tag alignment-record offset)
            (incf offset size))
       finally (return alignment-record))))

(defun flag-bits (flag &rest bit-names)
  "Returns an integer FLAG that had BAM flag bits named by symbols
BIT-NAMES set.

Arguments:

-  flag (unsigned-byte 8): a BAM alignment flag.

Rest:

- bit-names (symbols): Any number of valid bit flag names:

;;; :sequenced-pair
;;; :mapped-proper-pair
;;; :query-mapped , :query-unmapped
;;; :mate-mapped , :mate-unmapped
;;; :query-forward , :query-reverse
;;; :mate-forward , :mate-reverse
;;; :first-in-pair , :second-in-pair
;;; :alignment-primary , :alignment-not-primary
;;; :fails-platform-qc
;;; :pcr/optical-duplicate

Returns:

- An (unsigned-byte 8)"
  (let ((f flag))
    (dolist (name bit-names (ensure-valid-flag f))
      (destructuring-bind (bit value)
        (ecase name
          (:sequenced-pair        '( 0 1))
          (:mapped-proper-pair    '( 1 1))
          (:query-mapped          '( 2 0))
          (:query-unmapped        '( 2 1))
          (:mate-mapped           '( 3 0))
          (:mate-unmapped         '( 3 1))
          (:query-forward         '( 4 0))
          (:query-reverse         '( 4 1))
          (:mate-forward          '( 5 0))
          (:mate-reverse          '( 5 1))
          (:first-in-pair         '( 6 1))
          (:second-in-pair        '( 7 1))
          (:alignment-primary     '( 8 0))
          (:alignment-not-primary '( 8 1))
          (:fails-platform-qc     '( 9 1))
          (:pcr/optical-duplicate '(10 1)))
        (setf (ldb (byte 1 bit) f) value)))))

;; (declaim (ftype (function (bam-alignment) (unsigned-byte 32))
;;                 reference-id))
(declaim (inline reference-id))
(defun reference-id (alignment-record)
  "Returns the reference sequence identifier of ALIGNMENT-RECORD. This
is an integer locally assigned to a reference sequence within the
context of a BAM file."
  (declare (optimize (speed 3)))
  (decode-int32le alignment-record 0))

;; (declaim (ftype (function (bam-alignment) (unsigned-byte 32))
;;                 alignment-position))
(declaim (inline alignment-position))
(defun alignment-position (alignment-record)
  "Returns the 0-based sequence coordinate of ALIGNMENT-RECORD in the
reference sequence of the first base of the clipped read."
  (declare (optimize (speed 3)))
  (decode-int32le alignment-record 4))

(defun alignment-read-length (alignment-record)
  "Returns the length of the alignment on the read."
  (loop
     for (op . len) in (alignment-cigar alignment-record)
     when (member op '(:i :m :s)) sum len))

(defun alignment-reference-length (alignment-record)
  "Returns the length of the alignment on the reference."
  (loop
     for (op . len) in (alignment-cigar alignment-record)
     when (member op '(:d :m :n)) sum len))

(declaim (inline read-name-length))
(defun read-name-length (alignment-record)
  "Returns the length in ASCII characters of the read name of
ALIGNMENT-RECORD."
  (decode-uint8le alignment-record 8))

(defun mapping-quality (alignment-record)
  "Returns the integer mapping quality of ALIGNMENT-RECORD."
  (decode-uint8le alignment-record 9))

(defun alignment-bin (alignment-record)
  "Returns an integer that indicates the alignment bin to which
ALIGNMENT-RECORD has been assigned."
  (decode-uint16le alignment-record 10))

(defun cigar-length (alignment-record)
  "Returns the number of CIGAR operations in ALIGNMENT-RECORD."
  (decode-uint16le alignment-record 12))

(declaim (inline alignment-flag))
(defun alignment-flag (alignment-record &key (validate t))
  "Returns an integer whose bits are flags that describe properties of
the ALIGNMENT-RECORD. If the VALIDATE key is T (the default) the
flag's bits are checked for internal consistency."
  (let ((flag (decode-uint16le alignment-record 14)))
    (if validate
        (ensure-valid-flag flag alignment-record)
      flag)))

(defun sequenced-pair-p (flag)
  "Returns T if FLAG indicates that the read was sequenced as a member
of a pair, or NIL otherwise."
  (logbitp 0 flag))

(defun mapped-proper-pair-p (flag)
  "Returns T if FLAG indicates that the read was mapped as a member of
a properly oriented read-pair, or NIL otherwise."
  (logbitp 1 flag))

(defun query-unmapped-p (flag)
  "Returns T if FLAG indicates that the read was not mapped to a
reference, or NIL otherwise."
  (logbitp 2 flag))

(defun query-mapped-p (flag)
  "Returns T if FLAG indicates that the read's mate was mapped to a
reference, or NIL otherwise."
  (not (query-unmapped-p flag)))

(defun mate-unmapped-p (flag)
  "Returns T if FLAG indicates that the read's mate was not mapped to
a reference, or NIL otherwise."
  (logbitp 3 flag))

(defun mate-mapped-p (flag)
  "Returns T if FLAG indicates that the read's mate was mapped to a
reference, or NIL otherwise."
  (not (mate-unmapped-p flag)))

(declaim (inline query-forward-p))
(defun query-forward-p (flag)
  "Returns T if FLAG indicates that the read was mapped to the forward
strand of a reference, or NIL if it was mapped to the reverse strand."
  (not (query-reverse-p flag)))

(declaim (inline query-reverse-p))
(defun query-reverse-p (flag)
  "Returns T if FLAG indicates that the read was mapped to the reverse
strand of a reference, or NIL if it was mapped to the forward strand."
  (declare (type uint16 flag))
  (logbitp 4 flag))

(defun mate-forward-p (flag)
  "Returns T if FLAG indicates that the read's mate was mapped to the
forward, or NIL if it was mapped to the reverse strand."
  (not (mate-reverse-p flag)))

(defun mate-reverse-p (flag)
  "Returns T if FLAG indicates that the read's mate was mapped to the
reverse, or NIL if it was mapped to the forward strand."
  (logbitp 5 flag))

(defun first-in-pair-p (flag)
  "Returns T if FLAG indicates that the read was the first in a pair
of reads from one template, or NIL otherwise."
  (logbitp 6 flag))

(defun second-in-pair-p (flag)
  "Returns T if FLAG indicates that the read was the second in a pair
of reads from one template, or NIL otherwise."
  (logbitp 7 flag))

(defun alignment-not-primary-p (flag)
  "Returns T if FLAG indicates that the read mapping was not the
primary mapping to a reference, or NIL otherwise."
  (logbitp 8 flag))

(defun alignment-primary-p (flag)
  "Returns T if FLAG indicates that the read mapping was the primary
mapping to a reference, or NIL otherwise."
  (not (alignment-not-primary-p flag)))

(defun fails-platform-qc-p (flag)
  "Returns T if FLAG indicates that the read failed plaform quality
control, or NIL otherwise."
  (logbitp 9 flag))

(defun pcr/optical-duplicate-p (flag)
  "Returns T if FLAG indicates that the read is a PCR or optical
duplicate, or NIL otherwise."
  (logbitp 10 flag))

(defun valid-pair-num-p (flag)
  "Returns T if FLAG indicates a valid pair numbering, that is first and
not second or second and not first, or NIL otherwise."
  (or (and (first-in-pair-p flag) (not (second-in-pair-p flag)))
      (and (second-in-pair-p flag) (not (first-in-pair-p flag)))))

(defun valid-mapped-pair-p (flag)
  "Returns T if FLAG indicates valid mapping states for a pair of
mapped reads, that is both must be mapped, or NIL otherwise."
  (and (query-mapped-p flag) (mate-mapped-p flag)))

(defun valid-mapped-proper-pair-p (flag)
  "Returns T if FLAG indicates valid proper mapping states for a pair
of mapped reads, that is both must be mapped and on opposite strands,
or NIL otherwise."
  (and (valid-mapped-pair-p flag)
       (not (eql (query-forward-p flag) (mate-forward-p flag)))))

(defun valid-flag-p (flag)
  "Returns T if the paired-read-specific bits of FLAG are internally
consistent."
  (cond ((mapped-proper-pair-p flag)
         (and (sequenced-pair-p flag)
              (valid-pair-num-p flag)
              (valid-mapped-proper-pair-p flag)))
        ((sequenced-pair-p flag)
         (valid-pair-num-p flag))
        (t
         (not (or (mate-reverse-p flag) ; maybe ignore this one?
                  (mate-unmapped-p flag)
                  (first-in-pair-p flag)
                  (second-in-pair-p flag))))))

(defun read-length (alignment-record)
  "Returns the length of the read described by ALIGNMENT-RECORD."
  (decode-int32le alignment-record 16))

(defun mate-reference-id (alignment-record)
  "Returns the integer reference ID of ALIGNMENT-RECORD."
  (declare (optimize (speed 3)))
  (decode-int32le alignment-record 20))

(defun mate-alignment-position (alignment-record)
  "Returns the 0-based sequence position of the read mate's alignment
described by ALIGNMENT-RECORD."
  (decode-int32le alignment-record 24))

(defun insert-length (alignment-record)
  "Returns the insert length described by ALIGNMENT-RECORD."
  (decode-int32le alignment-record 28))

(defun read-name (alignment-record)
  "Returns the read name string described by ALIGNMENT-RECORD."
  (decode-read-name alignment-record 32
                    (read-name-length alignment-record)))

(defun alignment-cigar (alignment-record)
  "Returns the CIGAR record list of the alignment described by
ALIGNMENT-RECORD. CIGAR operations are given as a list, each member
being a list of a CIGAR operation keyword and an integer operation
length."
  (let* ((name-len (read-name-length alignment-record))
         (cigar-index (+ 32 name-len))
         (cigar-bytes (* 4 (cigar-length alignment-record))))
    (decode-cigar alignment-record cigar-index cigar-bytes)))

(defun seq-string (alignment-record)
  "Returns the sequence string described by ALIGNMENT-RECORD."
  (multiple-value-bind (read-len cigar-index cigar-bytes seq-index
                        qual-index tag-index)
      (alignment-indices alignment-record)
    (declare (ignore cigar-index cigar-bytes qual-index tag-index))
    (decode-seq-string alignment-record seq-index read-len)))

(defun quality-string (alignment-record)
  "Returns the sequence quality string described by ALIGNMENT-RECORD."
  (multiple-value-bind (read-len cigar-index cigar-bytes seq-index
                        qual-index tag-index)
      (alignment-indices alignment-record)
    (declare (ignore cigar-index cigar-bytes seq-index tag-index))
    (decode-quality-string alignment-record qual-index read-len)))

(defun alignment-tag-values (alignment-record)
  "Returns an alist of tag and values described by ALIGNMENT-RECORD."
  (multiple-value-bind (read-len cigar-index cigar-bytes seq-index
                        qual-index tag-index)
      (alignment-indices alignment-record)
    (declare (ignore read-len cigar-index cigar-bytes qual-index seq-index))
    (decode-tag-values alignment-record tag-index)))

(defun alignment-core (alignment-record &key (validate t))
  "Returns a list of the core data described by ALIGNMENT-RECORD. The
list elements are comprised of reference-id, alignment-position,
read-name length, mapping-quality alignment-bin, cigar length,
alignment flag, read length, mate reference-id, mate
alignment-position and insert length."
  (list (reference-id alignment-record)
        (alignment-position alignment-record)
        (read-name-length alignment-record)
        (mapping-quality alignment-record)
        (alignment-bin alignment-record)
        (cigar-length alignment-record)
        (alignment-flag alignment-record :validate validate)
        (read-length alignment-record)
        (mate-reference-id alignment-record)
        (mate-alignment-position alignment-record)
        (insert-length alignment-record)))

(defun alignment-core-alist (alignment-record &key (validate t))
  "Returns the same data as {defun alignment-core} in the form of an
alist."
  (pairlis '(:reference-id :alignment-pos :read-name-length
             :mapping-quality :alignment-bin :cigar-length
             :alignment-flag :read-length :mate-reference-id
             :mate-alignment-position :insert-length)
           (alignment-core alignment-record :validate validate)))

(defun alignment-flag-alist (alignment-record &key (validate t))
  "Returns the bitwise flags of ALIGNMENT-RECORD in the form of an
alist. The primary purpose of this function is debugging."
  (let ((flag (alignment-flag alignment-record :validate validate)))
    (pairlis '(:sequenced-pair :mapped-proper-pair :query-unmapped
               :mate-unmapped :query-forward :mate-forward :first-in-pair
               :second-in-pair :alignment-not-primary :fails-platform-qc
               :pcr/optical-duplicate)
             (list (sequenced-pair-p flag)
                   (mapped-proper-pair-p flag)
                   (query-unmapped-p flag)
                   (mate-unmapped-p flag)
                   (query-forward-p flag)
                   (mate-forward-p flag)
                   (first-in-pair-p flag)
                   (second-in-pair-p flag)
                   (alignment-not-primary-p flag)
                   (fails-platform-qc-p flag)
                   (pcr/optical-duplicate-p flag)))))

(defun alignment-indices (alignment-record)
  "Returns 7 integer values which are byte-offsets within
ALIGNMENT-RECORD at which the various core data lie. See the SAM
spec."
  (let* ((read-len (read-length alignment-record))
         (name-len (read-name-length alignment-record))
         (cigar-index (+ 32 name-len))
         (cigar-bytes (* 4 (cigar-length alignment-record)))
         (seq-index (+ cigar-index cigar-bytes))
         (seq-bytes (ceiling read-len 2))
         (qual-index (+ seq-index seq-bytes))
         (tag-index (+ qual-index read-len)))
    (values read-len cigar-index cigar-bytes seq-index qual-index tag-index)))

(defun decode-read-name (alignment-record index num-bytes)
  "Returns a string containing the template/read name of length
NUM-BYTES, encoded at byte INDEX in ALIGNMENT-RECORD."
  ;; The read name is null terminated and the terminator is included
  ;; in the name length
  (make-sb-string alignment-record index (- (+ index num-bytes) 2)))

(defun encode-read-name (read-name alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded READ-NAME into it, starting
at INDEX."
  (loop
     for i from 0 below (length read-name)
     for j = index then (1+ j)
     do (setf (aref alignment-record j) (char-code (char read-name i)))
     finally (setf (aref alignment-record (1+ j)) +null-byte+))
  alignment-record)

(defun decode-seq-string (alignment-record index num-bytes)
  "Returns a string containing the alignment query sequence of length
NUM-BYTES. The sequence must be present in ALIGNMENT-RECORD at INDEX."
  (declare (optimize (speed 3)))
  (declare (type (simple-array (unsigned-byte 8) (*)) alignment-record)
           (type (unsigned-byte 32) index num-bytes))
  (flet ((decode-base (nibble)
           (ecase nibble
             (0 #\=)
             (1 #\A)
             (2 #\C)
             (4 #\G)
             (8 #\T)
             (15 #\N))))
    (loop
       with seq = (make-array num-bytes :element-type 'base-char)
       for i from 0 below num-bytes
       for j of-type uint32 = (+ index (floor i 2))
       do (setf (char seq i)
                (decode-base (if (evenp i)
                                 (ldb (byte 4 4) (aref alignment-record j))
                               (ldb (byte 4 0) (aref alignment-record j)))))
       finally (return seq))))

(defun encode-seq-string (str alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded STR into it, starting at
INDEX."
  (flet ((encode-base (char)
           (ecase (char-upcase char)
             (#\= 0)
             (#\A 1)
             (#\C 2)
             (#\G 4)
             (#\T 8)
             (#\N 15))))
    (loop
       for i from 0 below (length str)
       for j = (+ index (floor i 2))
       for nibble = (encode-base (char str i))
       do (if (evenp i)
              (setf (ldb (byte 4 4) (aref alignment-record j)) nibble)
            (setf (ldb (byte 4 0) (aref alignment-record j)) nibble))
       finally (return alignment-record))))

(defun decode-quality-string (alignment-record index num-bytes)
  "Returns a string containing the alignment query sequence of length
NUM-BYTES. The sequence must be present in ALIGNMENT-RECORD at
INDEX. The SAM spec states that quality data are optional, with
absence indicated by 0xff. If the first byte of quality data is 0xff,
NIL is returned."
  (flet ((encode-phred (x)
           (code-char (+ 33 (min 93 x)))))
    (if (= #xff (aref alignment-record index))
        nil
      (loop
         with str = (make-array num-bytes :element-type 'base-char)
         for i from 0 below num-bytes
         for j from index below (+ index num-bytes)
         do (setf (char str i)
                  (encode-phred (decode-uint8le alignment-record j)))
         finally (return str)))))

(defun encode-quality-string (str alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded READ-NAME into it, starting
at INDEX."
  (flet ((decode-phred (x)
           (- (char-code x) 33)))
    (if (null str)
        (setf (aref alignment-record index) #xff)
      (loop
         for i from 0 below (length str)
         for j = (+ index i)
         do (encode-int8le (decode-phred (char str i))
                           alignment-record j))))
  alignment-record)

(defun decode-cigar (alignment-record index num-bytes)
  "Returns an alist of CIGAR operations from NUM-BYTES bytes within
ALIGNMENT-RECORD, starting at INDEX."
  (flet ((decode-len (uint32)
           (ash uint32 -4))
         (decode-op (uint32)
           (ecase (ldb (byte 4 0) uint32)
             (0 :m)
             (1 :i)
             (2 :d)
             (3 :n)
             (4 :s)
             (5 :h)
             (6 :p))))
    (loop
       for i from index below (1- (+ index num-bytes)) by 4
       collect (let ((x (decode-uint32le alignment-record i)))
                 (cons (decode-op x) (decode-len x))))))

(defun encode-cigar (cigar alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded alist CIGAR into it,
starting at INDEX."
  (flet ((encode-op-len (op len)
           (let ((uint32 (ash len 4)))
             (setf (ldb (byte 4 0) uint32) (ecase op
                                             (:m 0)
                                             (:i 1)
                                             (:d 2)
                                             (:n 3)
                                             (:s 4)
                                             (:h 5)
                                             (:p 6)))
             uint32)))
    (loop
       for (op . length) in cigar
       for i = index then (+ 4 i)
       do (encode-int32le (encode-op-len op length) alignment-record i)
       finally (return alignment-record))))

(defun decode-tag-values (alignment-record index)
  "Returns a list of auxilliary data from ALIGNMENT-RECORD at
INDEX. The BAM two-letter data keys are transformed to Lisp keywords."
  (declare (optimize (speed 3) (safety 0)))
  (declare (type (simple-array (unsigned-byte 8)) alignment-record)
           (type fixnum index))
  (loop
     with tag-index of-type fixnum = index
     while (< tag-index (length alignment-record))
     collect (let* ((type-index (+ tag-index +tag-size+))
                    (type-code (code-char (aref alignment-record type-index)))
                    (tag (intern (make-sb-string alignment-record tag-index
                                                 (1+ tag-index)) 'keyword))
                    (val-index (1+ type-index)))
               (declare (type fixnum val-index))
               (let  ((val (ecase type-code
                             (#\A         ; A printable character
                              (setf tag-index (+ val-index 1))
                              (code-char (aref alignment-record val-index)))
                             (#\C         ; C unsigned 8-bit integer
                              (setf tag-index (+ val-index 1))
                              (decode-uint8le alignment-record val-index))
                             ((#\H #\Z) ; H hex string, Z printable string
                              (let ((end (position +null-byte+ alignment-record
                                                   :start val-index)))
                                (setf tag-index (1+ end))
                                (make-sb-string alignment-record val-index
                                                (1- end))))
                             (#\I         ; I unsigned 32-bit integer
                              (setf tag-index (+ val-index 4))
                              (decode-uint32le alignment-record val-index))
                             (#\S         ; S unsigned short
                              (setf tag-index (+ val-index 2))
                              (decode-uint16le alignment-record val-index))
                             (#\c         ; c signed 8-bit integer
                              (setf tag-index (+ val-index 1))
                              (decode-int8le alignment-record val-index))
                             (#\f         ; f single-precision float
                              (setf tag-index (+ val-index 4))
                              (decode-float32le alignment-record val-index))
                             (#\i         ; i signed 32-bit integer
                              (setf tag-index (+ val-index 4))
                              (decode-int32le alignment-record val-index))
                             (#\s         ; s signed short
                              (setf tag-index (+ val-index 2))
                              (decode-int16le alignment-record val-index)))))
                 (cons tag val)))))

(defun encode-int-tag (value alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded integer VALUE into it,
starting at INDEX. BAM format is permitted to use more compact integer
storage where possible."
  (destructuring-bind (type-char encoder)
      (etypecase value
        ((integer 0 255)                  '(#\C encode-int8le))
        ((integer -128 127)               '(#\c encode-int8le))
        ((integer 0 65535)                '(#\S encode-int16le))
        ((integer -32768 32767)           '(#\s encode-int16le))
        ((integer -2147483648 2147483647) '(#\I encode-int32le))
        ((integer 0 4294967295)           '(#\i encode-int32le)))
    (setf (aref alignment-record index) (char-code type-char))
    (funcall encoder value alignment-record (1+ index))))

(defun encode-float-tag (value alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded float VALUE into it,
starting at INDEX."
  (setf (aref alignment-record index) (char-code #\f))
  (encode-float32le value alignment-record (1+ index)))

(defun encode-char-tag (value alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded character VALUE into it,
starting at INDEX."
  (setf (aref alignment-record index) (char-code #\A))
  (encode-int8le (char-code value) alignment-record (1+ index)))

(defun encode-hex-tag (value alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded hex string VALUE into it,
starting at INDEX."
  (when (parse-integer value :radix 16)
    (setf (aref alignment-record index) (char-code #\H))
    (%encode-string-tag value alignment-record (1+ index)) ))

(defun encode-string-tag (value alignment-record index)
  "Returns ALIGNMENT-RECORD having encoded string VALUE into it,
starting at INDEX."
  (setf (aref alignment-record index) (char-code #\Z))
  (%encode-string-tag value alignment-record (1+ index)))

(declaim (inline %encode-string-tag))
(defun %encode-string-tag (value alignment-record index)
  (let* ((len (length value))
         (term-index (+ index len)))
    (loop
       for i from 0 below len
       for j = index then (1+ j)
       do (setf (aref alignment-record j) (char-code (char value i)))
       finally (setf (aref alignment-record term-index) +null-byte+))
    alignment-record))

(defun alignment-tag-bytes (value)
  "Returns the number of bytes required to encode VALUE."
  (etypecase value
    (character 4)
    (string (+ 4 (length value)))       ; includes null byte
    (single-float 7)
    ((integer 0 255) 4)
    ((integer -128 127) 4)
    ((integer 0 65535) 5)
    ((integer -32768 32767) 5)
    ((integer -2147483648 2147483647) 7)
    ((integer 0 4294967295) 7)))

(defun ensure-valid-flag (flag &optional alignment-record)
  (cond ((mapped-proper-pair-p flag)
         (cond ((not (sequenced-pair-p flag))
                (flag-validation-error
                 flag (txt "the sequenced-pair bit was not set in a mapped"
                           "proper pair flag") alignment-record))
               ((not (valid-pair-num-p flag))
                (flag-validation-error
                 flag (txt "both first-in-pair and second-in-pair bits"
                           "were set") alignment-record))
               ((not (valid-mapped-pair-p flag))
                (flag-validation-error
                 flag (txt "one read was marked as unmapped in a mapped"
                           "proper pair flag") alignment-record))
               ((not (valid-mapped-proper-pair-p flag))
                (flag-validation-error
                 flag (txt "reads were not mapped to opposite strands in a"
                           "mapped proper pair flag") alignment-record))
               (t
                flag)))
        ((sequenced-pair-p flag)
         (if (valid-pair-num-p flag)
             flag
           (flag-validation-error
            flag "first-in-pair and second-in-pair bits were both set"
            alignment-record)))
        (t
         (cond ((mate-reverse-p flag)
                (flag-validation-error
                 flag "the mate-reverse bit was set in an unpaired read"
                 alignment-record))
               ((mate-unmapped-p flag)
                (flag-validation-error
                 flag "the mate-unmapped bit was set in an unpaired read"
                 alignment-record))
               ((first-in-pair-p flag)
                (flag-validation-error
                 flag "the first-in-pair bit was set in an unpaired read"
                 alignment-record))
               ((second-in-pair-p flag)
                (flag-validation-error
                 flag "the second-in-pair bit was set in an unpaired read"
                 alignment-record))
               (t
                flag)))))

(defun flag-validation-error (flag message &optional alignment-record)
  "Raised a {define-condition malformed-field-error} for alignment
FLAG in ALIGNMENT-RECORD, with MESSAGE."
  (if alignment-record
      (let ((reference-id (reference-id alignment-record))
            (read-name (read-name alignment-record))
            (pos (alignment-position alignment-record)))
        (error 'malformed-field-error
               :field flag
               :text (format nil (txt "invalid flag ~b set for read ~s at ~a"
                                      "in reference ~d: ~a")
                             flag read-name pos reference-id message)))
    (error 'malformed-field-error
           :field flag
           :text (format nil "invalid flag ~b set: ~a" flag message))))
