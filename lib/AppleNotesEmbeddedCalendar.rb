##
# This class represents a com.apple.ical.ics object embedded
# in an AppleNote. This means you added a calendar object to a note from another application, 
# like iCal.
class AppleNotesEmbeddedCalendar < AppleNotesEmbeddedObject

  attr_accessor :primary_key,
                :uuid,
                :type,
                :filepath,
                :filename,
                :reference_location

  ## 
  # Creates a new AppleNotesEmbeddedCalendar object. 
  # Expects an Integer +primary_key+ from ZICCLOUDSYNCINGOBJECT.Z_PK, String +uuid+ from ZICCLOUDSYNCINGOBJECT.ZIDENTIFIER, 
  # String +uti+ from ZICCLOUDSYNCINGOBJECT.ZTYPEUTI, AppleNote +note+ object representing the parent AppleNote, and 
  # AppleBackup +backup+ from the parent AppleNote. Immediately sets the +filename+ and +filepath+ to point to were the ics file is stored. 
  # Finally, it attempts to copy the file to the output folder.
  def initialize(primary_key, uuid, uti, note, backup)
    # Set this folder's variables
    super(primary_key, uuid, uti, note)
    @filename = get_media_filename
    @filepath = get_media_filepath
    @backup = backup

    # Find where on this computer that file is stored
    @backup_location = @backup.get_real_file_path(@filepath)
    
    # Copy the file to our output directory if we can
    @reference_location = @backup.back_up_file(@filepath, 
                                               @filename, 
                                               @backup_location, 
                                               @is_password_protected,
                                               @crypto_password,
                                               @crypto_salt,
                                               @crypto_iterations,
                                               @crypto_key,
                                               @crypto_asset_iv,
                                               @crypto_asset_tag)
  end

  ##
  # This method just returns a readable String for the object. 
  # Adds to the AppleNotesEmbeddedObject.to_s by pointing to where the media is.
  def to_s
    to_s_with_data("iCal ICS")
  end

  ##
  # This method returns the +uuid+ of the media.
  def get_media_uuid
    get_media_uuid_from_zidentifier
  end

  ##
  # This method returns the +filepath+ of this object. 
  # This is computed based on the assumed default storage location.
  def get_media_filepath
    get_media_filepath_with_uuid_and_filename
  end

  ##
  # This method returns the +filename+ of this object. 
  # This requires looking up the referenced ZICCLOUDSYNCINGOBJECT in the row 
  # identified by +uuid+. After that, the ZICCLOUDSYNCINGOBJECT.ZFILENAME 
  # field holds the answer.
  def get_media_filename
    get_media_filename_from_zfilename
  end

  ##
  # This method generates the HTML necessary to display the image inline.
  def generate_html
    generate_html_with_link("iCal ICS")
  end

end
