// ***************************************************************** -*- C++ -*-
/*
 * Copyright (C) 2004 Andreas Huggel <ahuggel@gmx.net>
 * 
 * This program is part of the Exiv2 distribution.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
/*!
  @file    exif.hpp
  @brief   Encoding and decoding of Exif data
  @version $Rev: 486 $
  @author  Andreas Huggel (ahu)
           <a href="mailto:ahuggel@gmx.net">ahuggel@gmx.net</a>
  @date    09-Jan-04, ahu: created
 */
#ifndef EXIF_HPP_
#define EXIF_HPP_

// *****************************************************************************
// included header files
#include "metadatum.hpp"
#include "types.hpp"
#include "error.hpp"
#include "image.hpp"
#include "value.hpp"
#include "ifd.hpp"
#include "tags.hpp"

// + standard includes
#include <string>
#include <vector>
#include <memory>

// *****************************************************************************
// namespace extensions
/*!
  @brief Provides classes and functions to encode and decode Exif and Iptc data.
         This namespace corresponds to the <b>libexiv2</b> library. 

 */
namespace Exiv2 {

// *****************************************************************************
// class declarations
    class ExifData;
    class MakerNote;

// *****************************************************************************
// class definitions

    /*!
      @brief Information related to one Exif tag. An Exif metadatum consists of
             an ExifKey and a Value and provides methods to manipulate these.
     */
    class Exifdatum : public Metadatum {
        friend std::ostream& operator<<(std::ostream&, const Exifdatum&);
        template<typename T> friend Exifdatum& setValue(Exifdatum&, const T&);
    public:
        //! @name Creators
        //@{
        /*!
          @brief Constructor for new tags created by an application. The
                 %Exifdatum is created from a \em key / value pair. %Exifdatum copies
                 (clones) the \em key and value if one is provided. Alternatively, 
                 a program can create an 'empty' %Exifdatum with only a key
                 and set the value using setValue().

          @param key %ExifKey.
          @param pValue Pointer to an %Exifdatum value.
          @throw Error ("Invalid key") if the key cannot be parsed and converted.
         */
        explicit Exifdatum(const ExifKey& key, const Value* pValue =0);
        //! Constructor to build an %Exifdatum from an IFD entry.
        Exifdatum(const Entry& e, ByteOrder byteOrder);
        //! Copy constructor
        Exifdatum(const Exifdatum& rhs);
        //! Destructor
        virtual ~Exifdatum();
        //@}

        //! @name Manipulators
        //@{
        //! Assignment operator
        Exifdatum& operator=(const Exifdatum& rhs);
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to UShortValue.
         */
        Exifdatum& operator=(const uint16_t& value); 
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to ULongValue.
         */
        Exifdatum& operator=(const uint32_t& value);
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to URationalValue.
         */
        Exifdatum& operator=(const URational& value);
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to ShortValue.
         */
        Exifdatum& operator=(const int16_t& value);
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to LongValue.
         */
        Exifdatum& operator=(const int32_t& value);
        /*!
          @brief Assign \em value to the %Exifdatum. The type of the new Value
                 is set to RationalValue.
         */
        Exifdatum& operator=(const Rational& value);
        /*!
          @brief Assign \em value to the %Exifdatum.
                 Calls setValue(const std::string&).                 
         */
        Exifdatum& operator=(const std::string& value);
        /*!
          @brief Assign \em value to the %Exifdatum.
                 Calls setValue(const Value*).
         */
        Exifdatum& operator=(const Value& value);
        /*!
          @brief Set the value. This method copies (clones) the value pointed
                 to by \em pValue.
         */
        void setValue(const Value* pValue);
        /*!
          @brief Set the value to the string \em value. 
                 Uses Value::read(const std::string&). If the %Exifdatum
                 does not have a value yet, then an AsciiValue is created.
         */
        void setValue(const std::string& value);
        /*!
          @brief Set the value from an IFD entry.
         */
        void setValue(const Entry& e, ByteOrder byteOrder);
        /*!
          @brief Set the data area by copying (cloning) the buffer pointed to 
                 by \em buf.

          Values may have a data area, which can contain additional
          information besides the actual value. This method is used to set such
          a data area.

          @param buf Pointer to the source data area
          @param len Size of the data area
          @return Return -1 if the %Exifdatum does not have a value yet or the
                  value has no data area, else 0.
         */
        int setDataArea(const byte* buf, long len) 
            { return value_.get() == 0 ? -1 : value_->setDataArea(buf, len); }
        //@}

        //! @name Accessors
        //@{
        //! Return the key of the %Exifdatum. 
        std::string key() const 
            { return key_.get() == 0 ? "" : key_->key(); }
        //! Return the name of the group (the second part of the key)
        std::string groupName() const
            { return key_.get() == 0 ? "" : key_->groupName(); }
        //! Return the name of the tag (which is also the third part of the key)
        std::string tagName() const
            { return key_.get() == 0 ? "" : key_->tagName(); }
        //! Return the tag
        uint16_t tag() const
            { return key_.get() == 0 ? 0xffff : key_->tag(); }
        //! Return the IFD id
        IfdId ifdId() const 
            { return key_.get() == 0 ? ifdIdNotSet : key_->ifdId(); }
        //! Return the name of the IFD
        const char* ifdName() const
            { return key_.get() == 0 ? "" : key_->ifdName(); }
        //! Return the related image item (deprecated)
        std::string ifdItem() const 
            { return key_.get() == 0 ? "" : key_->ifdItem(); }
        //! Return the index (unique id of this key within the original IFD)
        int idx() const
            { return key_.get() == 0 ? 0 : key_->idx(); }
        /*!
          @brief Write value to a data buffer and return the number
                 of bytes written.

          The user must ensure that the buffer has enough memory. Otherwise
          the call results in undefined behaviour.

          @param buf Data buffer to write to.
          @param byteOrder Applicable byte order (little or big endian).
          @return Number of characters written.
        */
        long copy(byte* buf, ByteOrder byteOrder) const 
            { return value_.get() == 0 ? 0 : value_->copy(buf, byteOrder); }
        //! Return the type id of the value
        TypeId typeId() const 
            { return value_.get() == 0 ? invalidTypeId : value_->typeId(); }
        //! Return the name of the type
        const char* typeName() const 
            { return TypeInfo::typeName(typeId()); }
        //! Return the size in bytes of one component of this type
        long typeSize() const 
            { return TypeInfo::typeSize(typeId()); }
        //! Return the number of components in the value
        long count() const 
            { return value_.get() == 0 ? 0 : value_->count(); }
        //! Return the size of the value in bytes
        long size() const 
            { return value_.get() == 0 ? 0 : value_->size(); }
        //! Return the value as a string.
        std::string toString() const 
            { return value_.get() == 0 ? "" : value_->toString(); }
        /*!
          @brief Return the <EM>n</EM>-th component of the value converted to
                 long. The return value is -1 if the value of the Exifdatum is
                 not set and the behaviour of the method is undefined if there
                 is no n-th component.
         */
        long toLong(long n =0) const 
            { return value_.get() == 0 ? -1 : value_->toLong(n); }
        /*!
          @brief Return the <EM>n</EM>-th component of the value converted to
                 float.  The return value is -1 if the value of the Exifdatum is
                 not set and the behaviour of the method is undefined if there
                 is no n-th component.
         */
        float toFloat(long n =0) const 
            { return value_.get() == 0 ? -1 : value_->toFloat(n); }
        /*!
          @brief Return the <EM>n</EM>-th component of the value converted to
                 Rational. The return value is -1/1 if the value of the
                 Exifdatum is not set and the behaviour of the method is
                 undefined if there is no n-th component.
         */
        Rational toRational(long n =0) const 
            { return value_.get() == 0 ? Rational(-1, 1) : value_->toRational(n); }
        /*!
          @brief Return an auto-pointer to a copy (clone) of the value. The
                 caller owns this copy and the auto-pointer ensures that it will
                 be deleted.

          This method is provided for users who need full control over the 
          value. A caller may, e.g., downcast the pointer to the appropriate
          subclass of Value to make use of the interface of the subclass to set
          or modify its contents.
          
          @return An auto-pointer to a copy (clone) of the value, 0 if the value
                  is not set.
         */
        Value::AutoPtr getValue() const 
            { return value_.get() == 0 ? Value::AutoPtr(0) : value_->clone(); }
        /*!
          @brief Return a constant reference to the value. 

          This method is provided mostly for convenient and versatile output of
          the value which can (to some extent) be formatted through standard
          stream manipulators.  Do not attempt to write to the value through
          this reference. 

          <b>Example:</b> <br>
          @code
          ExifData::const_iterator i = exifData.findKey(key);
          if (i != exifData.end()) {
              std::cout << i->key() << " " << std::hex << i->value() << "\n";
          }
          @endcode

          @return A constant reference to the value.
          @throw Error ("Value not set") if the value is not set.
         */
        const Value& value() const 
            { if (value_.get() != 0) return *value_; throw Error("Value not set"); }
        //! Return the size of the data area.
        long sizeDataArea() const 
            { return value_.get() == 0 ? 0 : value_->sizeDataArea(); }
        /*!
          @brief Return a copy of the data area of the value. The caller owns
                 this copy and %DataBuf ensures that it will be deleted.

          Values may have a data area, which can contain additional
          information besides the actual value. This method is used to access
          such a data area.

          @return A %DataBuf containing a copy of the data area or an empty
                  %DataBuf if the value does not have a data area assigned or the
                  value is not set.
         */
        DataBuf dataArea() const
            { return value_.get() == 0 ? DataBuf(0, 0) : value_->dataArea(); }

        //@}

    private:
        // DATA
        ExifKey::AutoPtr key_;                  //!< Key 
        Value::AutoPtr   value_;                //!< Value

    }; // class Exifdatum

    /*!
      @brief Output operator for Exifdatum types, prints the interpreted
             tag value.
     */
    std::ostream& operator<<(std::ostream& os, const Exifdatum& md);

    /*!
      @brief Set the value of \em exifDatum to \em value. If the object already
             has a value, it is replaced. Otherwise a new ValueType\<T\> value
             is created and set to \em value. 

      This is a helper function, called from Exifdatum members. It is meant to
      be used with T = (u)int16_t, (u)int32_t or (U)Rational. Do not use directly.
    */
    template<typename T>
    Exifdatum& setValue(Exifdatum& exifDatum, const T& value);

    /*!
      @brief Exif %Thumbnail image. This abstract base class provides the
             interface for the thumbnail image that is optionally embedded in
             the Exif data. This class is used internally by ExifData, it is
             probably not useful for a client as a standalone class.  Instead,
             use an instance of ExifData to access the Exif thumbnail image.
     */
    class Thumbnail {
    public:
        //! Shortcut for a %Thumbnail auto pointer.
        typedef std::auto_ptr<Thumbnail> AutoPtr;

        //! @name Creators
        //@{
        //! Virtual destructor
        virtual ~Thumbnail() {}
        //@}

        //! @name Accessors
        //@{
        /*!
          @brief Set the image data as data area of the appropriate Exif
                 metadatum. Read the thumbnail image data from data buffer 
                 \em buf. Return 0 if successful.

          @param exifData Exif data corresponding to the data buffer.
          @param ifd1 Corresponding raw IFD1.
          @param buf Data buffer containing the thumbnail data. The buffer must
                 start with the TIFF header.
          @param len Number of bytes in the data buffer.
          @return 0 if successful;<BR>
                  1 in case of inconsistent thumbnail Exif data; or<BR>
                  2 if the data area is outside of the data buffer
         */
        virtual int setDataArea(ExifData& exifData, 
                                Ifd& ifd1,
                                const byte* buf,
                                long len) const =0;
        /*!
          @brief Return the thumbnail image in a %DataBuf. The caller owns the
                 data buffer and %DataBuf ensures that it will be deleted.
         */
        virtual DataBuf copy(const ExifData& exifData) const =0;
        /*!
          @brief Return a short string for the format of the thumbnail 
                 ("TIFF", "JPEG").
         */
        virtual const char* format() const =0;
        /*!
          @brief Return the file extension for the format of the thumbnail 
                 (".tif", ".jpg").
         */
        virtual const char* extension() const =0;
        //@}

    protected:
        //! @name Manipulators
        //@{
        /*!
          @brief Assignment operator. Protected so that it can only be used
                 by subclasses but not directly.
         */
        Thumbnail& operator=(const Thumbnail& rhs);
        //@}

    }; // class Thumbnail

    //! Exif thumbnail image in TIFF format
    class TiffThumbnail : public Thumbnail {
    public:
        //! Shortcut for a %TiffThumbnail auto pointer.
        typedef std::auto_ptr<TiffThumbnail> AutoPtr;

        //! @name Manipulators
        //@{
        //! Assignment operator.
        TiffThumbnail& operator=(const TiffThumbnail& rhs) { return *this; }
        //@}

        //! @name Accessors
        //@{
        int setDataArea(ExifData& exifData, 
                        Ifd& ifd1, 
                        const byte* buf,
                        long len) const;
        DataBuf copy(const ExifData& exifData) const;
        const char* format() const;
        const char* extension() const;
        //@}

    }; // class TiffThumbnail

    //! Exif thumbnail image in JPEG format
    class JpegThumbnail : public Thumbnail {
    public:
        //! Shortcut for a %JpegThumbnail auto pointer.
        typedef std::auto_ptr<JpegThumbnail> AutoPtr;

        //! @name Manipulators
        //@{
        //! Assignment operator.
        JpegThumbnail& operator=(const JpegThumbnail& rhs) { return *this; }
        //@}

        //! @name Accessors
        //@{
        int setDataArea(ExifData& exifData, 
                        Ifd& ifd1, 
                        const byte* buf,
                        long len) const;
        DataBuf copy(const ExifData& exifData) const;
        const char* format() const;
        const char* extension() const;
        //@}

    }; // class JpegThumbnail

    //! Container type to hold all metadata
    typedef std::vector<Exifdatum> ExifMetadata;

    //! Unary predicate that matches a Exifdatum with a given ifd id and idx
    class FindMetadatumByIfdIdIdx {
    public:
        //! Constructor, initializes the object with the ifd id and idx to look for
        FindMetadatumByIfdIdIdx(IfdId ifdId, int idx)
            : ifdId_(ifdId), idx_(idx) {}
        /*!
          @brief Returns true if the ifd id and idx of the argument
                 \em exifdatum is equal to that of the object.
        */
        bool operator()(const Exifdatum& exifdatum) const
            { return ifdId_ == exifdatum.ifdId() && idx_ == exifdatum.idx(); }

    private:
        IfdId ifdId_;
        int idx_;
        
    }; // class FindMetadatumByIfdIdIdx

    /*!
      @brief A container for Exif data.  This is a top-level class of the %Exiv2
             library. The container holds Exifdatum objects.

      Provide high-level access to the Exif data of an image:
      - read Exif information from JPEG files
      - access metadata through keys and standard C++ iterators
      - add, modify and delete metadata 
      - write Exif data to JPEG files
      - extract Exif metadata to files, insert from these files
      - extract and delete Exif thumbnail (JPEG and TIFF thumbnails)
    */
    class ExifData {
        //! @name Not implemented
        //@{
        //@}
    public:
        //! ExifMetadata iterator type
        typedef ExifMetadata::iterator iterator;
        //! ExifMetadata const iterator type
        typedef ExifMetadata::const_iterator const_iterator;

        //! @name Creators
        //@{
        //! Default constructor
        ExifData();
        //! Copy constructor (Todo: copy image data also)
        ExifData(const ExifData& rhs);
        //! Destructor
        ~ExifData();
        //@}

        //! @name Manipulators
        //@{
        //! Assignment operator (Todo: assign image data also)
        ExifData& operator=(const ExifData& rhs);
        /*!
          @brief Read the Exif data from file \em path.
          @param path Path to the file
          @return  0 if successful;<BR>
                   3 if the file contains no Exif data;<BR>
                  the return code of Image::readMetadata()
                    if the call to this function fails<BR>
                  the return code of read(const char* buf, long len)
                    if the call to this function fails
         */
        int read(const std::string& path);
        /*!
          @brief Read the Exif data from a byte buffer. The data buffer
                 must start with the TIFF header.
          @param buf Pointer to the data buffer to read from
          @param len Number of bytes in the data buffer 
          @return 0 if successful.
         */
        int read(const byte* buf, long len);
        /*!
          @brief Write the Exif data to file \em path. If an Exif data section
                 already exists in the file, it is replaced.  If there is no
                 metadata and no thumbnail to write, the Exif data section is
                 deleted from the file.  Otherwise, an Exif data section is
                 created. See copy(byte* buf) for further details.

          @return 0 if successful.
         */
        int write(const std::string& path);
        /*!
          @brief Write the Exif data to a binary file. By convention, the
                 filename extension should be ".exv". This file format contains
                 the Exif data as it is found in a JPEG file, starting with the
                 APP1 marker 0xffe1, the size of the data and the string
                 "Exif\0\0". Exv files can be read with 
                 int read(const std::string& path) just like image Exif data.
         */
        int writeExifData(const std::string& path);
        /*!
          @brief Write the Exif data to a data buffer, which is returned.  The
                 caller owns this copy and %DataBuf ensures that it will be
                 deleted.  The copied data starts with the TIFF header.

          Tries to update the original data buffer and write it back with
          minimal changes, in a 'non-intrusive' fashion, if possible. In this
          case, tag data that ExifData does not understand stand a good chance
          to remain valid. (In particular, if the Exif data contains a
          Makernote in IFD format, the offsets in its IFD will remain valid.)
          <BR>
          If 'non-intrusive' writing is not possible, the Exif data will be
          re-built from scratch, in which case the absolute position of the
          metadata entries within the data buffer may (and in most cases will)
          be different from their original position. Furthermore, in this case,
          the Exif data is updated with the metadata from the actual thumbnail
          image (overriding existing metadata).

          @return A %DataBuf containing the Exif data.
         */
        DataBuf copy();
        /*!
          @brief Returns a reference to the %Exifdatum that is associated with a
                 particular \em key. If %ExifData does not already contain such
                 an %Exifdatum, operator[] adds object \em Exifdatum(key).

          @note  Since operator[] might insert a new element, it can't be a const
                 member function.
         */
        Exifdatum& operator[](const std::string& key);
        /*!
          @brief Add all (IFD) entries in the range from iterator position begin
                 to iterator position end to the Exif metadata. No duplicate
                 checks are performed, i.e., it is possible to add multiple
                 metadata with the same key.
         */
        void add(Entries::const_iterator begin, 
                 Entries::const_iterator end,
                 ByteOrder byteOrder);
        /*!
          @brief Add an Exifdatum from the supplied key and value pair.  This
                 method copies (clones) key and value. No duplicate checks are
                 performed, i.e., it is possible to add multiple metadata with
                 the same key.
         */
        void add(const ExifKey& key, const Value* pValue);
        /*!
          @brief Add a copy of the \em exifdatum to the Exif metadata.  No
                 duplicate checks are performed, i.e., it is possible to add
                 multiple metadata with the same key.

          @throw Error ("Inconsistent MakerNote") if \em exifdatum is a MakerNote
                 tag for a different %MakerNote than that of the %ExifData.
         */
        void add(const Exifdatum& exifdatum);
        /*!
          @brief Delete the Exifdatum at iterator position \em pos, return the 
                 position of the next exifdatum. Note that iterators into
                 the metadata, including \em pos, are potentially invalidated 
                 by this call.
         */
        iterator erase(iterator pos);
        //! Sort metadata by key
        void sortByKey();
        //! Sort metadata by tag
        void sortByTag();
        //! Begin of the metadata
        iterator begin() { return exifMetadata_.begin(); }
        //! End of the metadata
        iterator end() { return exifMetadata_.end(); }
        /*!
          @brief Find a Exifdatum with the given \em key, return an iterator to
                 it.  If multiple metadata with the same key exist, it is
                 undefined which of the matching metadata is found.
         */
        iterator findKey(const ExifKey& key);
        /*!
          @brief Find the Exifdatum with the given \em ifdId and \em idx,
                 return an iterator to it. 

          This method can be used to uniquely identify an exifdatum that was
          created from an IFD or from the makernote (with idx greater than
          0). Metadata created by an application (not read from an IFD or a
          makernote) all have their idx field set to 0, i.e., they cannot be
          uniquely identified with this method.  If multiple metadata with the
          same key exist, it is undefined which of the matching metadata is
          found.
         */
        iterator findIfdIdIdx(IfdId ifdId, int idx);
        /*!
          @brief Set the Exif thumbnail to the Jpeg image \em path. Set
                 XResolution, YResolution and ResolutionUnit to \em xres,
                 \em yres and \em unit, respectively.

          This results in the minimal thumbnail tags being set for a Jpeg
          thumbnail, as mandated by the Exif standard.

          @note  No checks on the file format or size are performed.
          @note  Additional existing Exif thumbnail tags are not modified.

          @throw Error ("Couldn't open input file") if fopen fails,
          @throw Error ("Couldn't stat input file") if stat fails, or
          @throw Error ("Couldn't read input file") if fread fails.
         */
        void setJpegThumbnail(const std::string& path, 
                              URational xres, URational yres, uint16_t unit);
        /*!
          @brief Set the Exif thumbnail to the Jpeg image pointed to by \em buf,
                 and size \em size. Set XResolution, YResolution and
                 ResolutionUnit to \em xres, \em yres and \em unit, respectively.

          This results in the minimal thumbnail tags being set for a Jpeg
          thumbnail, as mandated by the Exif standard.

          @note  No checks on the image format or size are performed.
          @note  Additional existing Exif thumbnail tags are not modified.
         */
        void setJpegThumbnail(const byte* buf, long size, 
                              URational xres, URational yres, uint16_t unit);
        /*!
          @brief Set the Exif thumbnail to the Jpeg image \em path. 

          This sets only the Compression, JPEGInterchangeFormat and
          JPEGInterchangeFormatLength tags, which is not all the thumbnail
          Exif information mandatory according to the Exif standard. (But it's
          enough to work with the thumbnail.)

          @note  No checks on the file format or size are performed.
          @note  Additional existing Exif thumbnail tags are not modified.

          @throw Error ("Couldn't open input file") if fopen fails,
          @throw Error ("Couldn't stat input file") if stat fails, or
          @throw Error ("Couldn't read input file") if fread fails.
         */
        void setJpegThumbnail(const std::string& path);
        /*!
          @brief Set the Exif thumbnail to the Jpeg image pointed to by \em buf,
                 and size \em size. 

          This sets only the Compression, JPEGInterchangeFormat and
          JPEGInterchangeFormatLength tags, which is not all the thumbnail
          Exif information mandatory according to the Exif standard. (But it's
          enough to work with the thumbnail.)

          @note  No checks on the image format or size are performed.
          @note  Additional existing Exif thumbnail tags are not modified.
         */
        void setJpegThumbnail(const byte* buf, long size);
        /*!
          @brief Delete the thumbnail from the Exif data. Removes all
                 Exif.%Thumbnail.*, i.e., IFD1 metadata.

          @return The number of bytes of thumbnail data erased from the original
                  Exif data. Note that the original image size may differ from
                  the size of the image after deleting the thumbnail by more
                  than this number. This is the case if the Exif data contains
                  extra bytes (often at the end of the Exif block) or gaps and
                  the thumbnail is not located at the end of the Exif block so
                  that non-intrusive writing of a truncated Exif block is not
                  possible. Instead it is in this case necessary to write the
                  Exif data, without the thumbnail, from the metadata and all
                  extra bytes and gaps are lost, resulting in a smaller image.
         */
        long eraseThumbnail();
        //@}

        //! @name Accessors
        //@{
        /*!
          @brief Erase the Exif data section from file \em path. 
          @param path Path to the file.
          @return 0 if successful.
         */
        int erase(const std::string& path) const;
        //! Begin of the metadata
        const_iterator begin() const { return exifMetadata_.begin(); }
        //! End of the metadata
        const_iterator end() const { return exifMetadata_.end(); }
        /*!
          @brief Find an exifdatum with the given \em key, return a const
                 iterator to it.  If multiple metadata with the same key exist,
                 it is undefined which of the matching metadata is found.
         */
        const_iterator findKey(const ExifKey& key) const;
        /*!
          @brief Find the exifdatum with the given \em ifdId and \em idx,
                 return an iterator to it. 

          This method can be used to uniquely identify a Exifdatum that was
          created from an IFD or from the makernote (with idx greater than
          0). Metadata created by an application (not read from an IFD or a
          makernote) all have their idx field set to 0, i.e., they cannot be
          uniquely identified with this method.  If multiple metadata with the
          same key exist, it is undefined which of the matching metadata is
          found.
         */
        const_iterator findIfdIdIdx(IfdId ifdId, int idx) const;
        //! Get the number of metadata entries
        long count() const { return static_cast<long>(exifMetadata_.size()); }
        //! Returns the byte order as specified in the TIFF header
        ByteOrder byteOrder() const { return tiffHeader_.byteOrder(); }
        /*!
          @brief Write the thumbnail image to a file. A filename extension
                 is appended to \em path according to the image type of the
                 thumbnail, so \em path should not include an extension.
                 This will overwrite an existing file of the same name.

          @param  path Path of the filename without image type extension
          @return 0 if successful;<BR>
                 -1 if opening the file failed;<BR>
                  4 if writing to the output stream failed;<BR>
                  8 if the Exif data does not contain a thumbnail
         */
        int writeThumbnail(const std::string& path) const; 
        /*!
          @brief Return the thumbnail image in a %DataBuf. The caller owns the
                 data buffer and %DataBuf ensures that it will be deleted.
         */
        DataBuf copyThumbnail() const;
        /*!
          @brief Return a short string describing the format of the Exif 
                 thumbnail ("TIFF", "JPEG").
         */
        const char* thumbnailFormat() const;
        /*!
          @brief Return the file extension for the Exif thumbnail depending
                 on the format (".tif", ".jpg").
         */
        const char* thumbnailExtension() const;
        /*!
          @brief Return a thumbnail object of the correct type, corresponding to
                 the current Exif data. Caller owns this object and the auto
                 pointer ensures that it will be deleted.
         */
        Thumbnail::AutoPtr getThumbnail() const;
        //@}

        /*!
          @brief Convert the return code \em rc from \n 
                 int read(const std::string& path); \n
                 int write(const std::string& path); \n
                 int writeExifData(const std::string& path); \n
                 int writeThumbnail(const std::string& path) const; and \n
                 int erase(const std::string& path) const \n
                 into an error message.

                 Todo: Implement global handling of error messages
         */
        static std::string strError(int rc, const std::string& path);

    private:
        //! @name Manipulators
        //@{
        /*!
          @brief Read the thumbnail from the data buffer. Assigns the thumbnail
                 data area with the appropriate Exif tags. Return 0 if successful,
                 i.e., if there is a thumbnail.
         */
        int readThumbnail();
        /*!
          @brief Check if the metadata changed and update the internal IFDs and
                 the MakerNote if the changes are compatible with the existing
                 data (non-intrusive write support). 

          @return True if only compatible changes were detected in the metadata
                  and the internal IFDs and MakerNote (and thus the data buffer)
                  were updated successfully. Return false, if non-intrusive
                  writing is not possible. The internal IFDs and the MakerNote
                  (and thus the data buffer) may or may not be modified in this
                  case.
         */
        bool updateEntries();
        /*!
          @brief Update the metadata for a range of entries. Called by
                 updateEntries() for each of the internal IFDs and the MakerNote
                 (if any).
         */
        bool updateRange(const Entries::iterator& begin,
                         const Entries::iterator& end,
                         ByteOrder byteOrder);
        /*!
          @brief Write the Exif data to a data buffer the hard way, return the
                 data buffer. The caller owns this data buffer and %DataBuf
                 ensures that it will be deleted. 

          Rebuilds the Exif data from scratch, using the TIFF header, metadata
          container and thumbnail. In particular, the internal IFDs and the
          original data buffer are not used. Furthermore, this method updates
          the Exif data with the metadata from the actual thumbnail image
          (overriding existing metadata).

          @return A %DataBuf containing the Exif data.
         */
        DataBuf copyFromMetadata();
        //@}

        //! @name Accessors
        //@{
        /*!
          @brief Check if the metadata is compatible with the internal IFDs for
                 non-intrusive writing. Return true if compatible, false if not.

          @note This function does not detect deleted metadata as incompatible,
                although the deletion of metadata is not (yet) a supported
                non-intrusive write operation.
         */
        bool compatible() const;
        /*!
          @brief Find the IFD or makernote entry corresponding to ifd id and idx.

          @return A pair of which the first part determines if a match was found
                  and, if true, the second contains an iterator to the entry.
         */
        std::pair<bool, Entries::const_iterator> 
        findEntry(IfdId ifdId, int idx) const;
        //! Return a pointer to the internal IFD identified by its IFD id
        const Ifd* getIfd(IfdId ifdId) const;
        /*! 
          @brief Check if IFD1, the IFD1 data and thumbnail data are located at 
                 the end of the Exif data. Return true, if they are or if there
                 is no thumbnail at all, else return false.
         */
        bool stdThumbPosition() const;
        //@}

        // DATA
        TiffHeader tiffHeader_;
        ExifMetadata exifMetadata_;
        //! Pointer to the MakerNote
        std::auto_ptr<MakerNote> makerNote_;

        Ifd ifd0_;
        Ifd exifIfd_;
        Ifd iopIfd_;
        Ifd gpsIfd_;
        Ifd ifd1_;

        long size_;              //!< Size of the Exif raw data in bytes
        byte* pData_;            //!< Exif raw data buffer

        /*!
          Can be set to false to indicate that non-intrusive writing is not
          possible. If it is true (the default), then the compatibility checks
          will be performed to determine which writing method to use.
         */
        bool compatible_;

    }; // class ExifData

// *****************************************************************************
// template, inline and free functions
    
    template<typename T>
    Exifdatum& setValue(Exifdatum& exifDatum, const T& value)
    {
        std::auto_ptr<ValueType<T> > v 
            = std::auto_ptr<ValueType<T> >(new ValueType<T>);
        v->value_.push_back(value);
        exifDatum.value_ = v;
        return exifDatum;
    }
    /*!
      @brief Add all metadata in the range from iterator position begin to
             iterator position end, which have an IFD id matching that of the
             IFD to the list of directory entries of ifd.  No duplicate checks
             are performed, i.e., it is possible to add multiple metadata with
             the same key to an IFD.
     */
    void addToIfd(Ifd& ifd,
                  ExifMetadata::const_iterator begin, 
                  ExifMetadata::const_iterator end, 
                  ByteOrder byteOrder);
    /*!
      @brief Add the Exifdatum to the IFD.  No duplicate checks are performed,
             i.e., it is possible to add multiple metadata with the same key to
             an IFD.
     */
    void addToIfd(Ifd& ifd, const Exifdatum& exifdatum, ByteOrder byteOrder);
    /*!
      @brief Add all metadata in the range from iterator position begin to
             iterator position end with IFD id 'makerIfd' to the list of
             makernote entries of the object pointed to be makerNote.  No
             duplicate checks are performed, i.e., it is possible to add
             multiple metadata with the same key to a makernote.
     */
    void addToMakerNote(MakerNote* makerNote,
                        ExifMetadata::const_iterator begin,
                        ExifMetadata::const_iterator end, 
                        ByteOrder byteOrder);
    /*!
      @brief Add the Exifdatum to makerNote, encoded in byte order byteOrder.
             No duplicate checks are performed, i.e., it is possible to add
             multiple metadata with the same key to a makernote.
     */
    void addToMakerNote(MakerNote* makerNote,
                        const Exifdatum& exifdatum,
                        ByteOrder byteOrder);

}                                       // namespace Exiv2

#endif                                  // #ifndef EXIF_HPP_