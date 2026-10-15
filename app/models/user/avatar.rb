# A player's picture. Uploads are never stored as they come: each is cropped to a small square and
# re-encoded without metadata, so a phone photo's location and camera details are thrown away
module User::Avatar
  extend ActiveSupport::Concern

  SIZE = 256
  MAX_UPLOAD_SIZE = 10.megabytes
  CONTENT_TYPES = %w[ image/jpeg image/png image/webp image/gif image/heic image/heif ]
  # Players without a picture get a letter on one of the four neon colours, the same one every time
  COLOURS = %w[ yellow green blue pink ]

  included do
    has_one_attached :avatar

    attr_reader :avatar_upload
    attribute :remove_avatar, :boolean, default: false

    validate :process_avatar_upload, if: :avatar_upload
    after_save_commit :finish_avatar_changes
  end

  def avatar_upload=(file)
    @avatar_upload = file.presence
  end

  def avatar_letter
    (username || name || "?").first.upcase
  end

  def avatar_colour
    COLOURS[id.to_i % COLOURS.size]
  end

  private
    def process_avatar_upload
      if !avatar_upload.respond_to?(:tempfile)
        errors.add(:avatar, "needs to be a photo or picture")
      elsif avatar_upload.size > MAX_UPLOAD_SIZE
        errors.add(:avatar, "is too big (the most is 10 MB)")
      elsif CONTENT_TYPES.exclude?(Marcel::MimeType.for(avatar_upload.tempfile, name: avatar_upload.original_filename))
        errors.add(:avatar, "needs to be a photo or picture")
      else
        processed = ImageProcessing::Vips
          .source(avatar_upload.tempfile)
          .resize_to_fill(SIZE, SIZE)
          .convert("webp")
          .saver(strip: true, Q: 82)
          .call
        # Assigned rather than attached, so Active Storage stores it as part of this save
        self.avatar = { io: processed, filename: "avatar.webp", content_type: "image/webp" }
      end
    rescue ImageProcessing::Error, Vips::Error
      errors.add(:avatar, "couldn't be read. Try a different picture")
    end

    # A new upload replaces the old picture anyway, so removing only applies without one.
    # The flags are cleared first: purging touches this record, which saves it and runs this again
    def finish_avatar_changes
      remove = remove_avatar && !avatar_upload
      self.remove_avatar = false
      @avatar_upload = nil
      avatar.purge if remove && avatar.attached?
    end
end
