require 'fileutils'
require 'systemu'

# File Utilities for use in transferring filesystem objects,
# decrypting a file, unpacking a targz archive, and validating checksums
# @author rnanders@stanford.edu
module LyberUtils
  class FileUtilities

    # Executes a system command in a subprocess.
    # The method will return stdout from the command if execution was successful.
    # The method will raise an exception if if execution fails.
    # The exception's message will contain the explanation of the failure.
    # @param [String] command the command to be executed
    # @return [String] stdout from the command if execution was successful
    def FileUtilities.execute(command)
      status, stdout, stderr = systemu(command)
      raise stderr if status.exitstatus != 0
      stdout
    rescue
      msg = "Command failed to execute: [#{command}] caused by <STDERR = #{stderr.split($/).join('; ')}>"
      msg << " STDOUT = #{stdout.split($/).join('; ')}" if (stdout && (stdout.length > 0))
      raise msg
    end

    # Generates a dirname for storing or retrieving a file in
    # "pair tree" hierarchical structure, where the path is derived
    # from segments of a barcode string
    #
    # = Input:
    # * barcode = barcode string
    #
    # = Return value:
    # * A string containing a slash-delimited dirname derived from the barcode
    def FileUtilities.pair_tree_from_barcode(barcode)
      raise "Barcode must be a String" if barcode.class != String
      # SUL barcode or from coordinate library?
      library_prefix = barcode[0..4]
      if library_prefix == '36105'
        pair_tree = barcode[5..10].gsub(/(..)/, '\1/')
      else
        library_prefix = barcode[0..2]
        pair_tree = barcode[3..8].gsub(/(..)/, '\1/')
      end
      "#{library_prefix}/#{pair_tree}"
    end

    # Transfers a filesystem object (file or directory)
    # from a source to a target location. Uses rsync in "archive" mode
    # over an ssh connection.
    #
    # = Inputs:
    # * filename = basename of the filesystem object to be transferred
    # * source_dir = dirname of the source location from which the object is read
    # * dest_dir = dirname of the target location to which the object is written
    # If one of the locations is on a remote server, then the dirname should be
    # prefixed with  user@hosthame:
    #
    # = Return value:
    # * The method will return true if the transfer is successful.
    # * The method will raise an exception if either the rsync command fails,
    # or a test for the existence of the transferred object fails.
    # The exception's message will contain the explanation of the failure
    #
    # Network transfers will only succeed if the appropriate public key
    # authentication has been previously set up.
    def FileUtilities.transfer_object(filename, source_dir, dest_dir)
      source_path = File.join(source_dir, filename)
      rsync_cmd = "rsync -a -e ssh '#{source_path}' #{dest_dir}"
      # LyberCore::Log.debug("rsync command is: #{rsync_cmd}")
      self.execute(rsync_cmd)
      raise "#{filename} is not found in #{dest_dir}" unless File.exists?(File.join(dest_dir, filename))
      true
    end

    # Decrypts a GPG encrypted file using the "gpg" command
    #
    # = Inputs:
    # * workspace_dir = dirname containing the file
    # * targzgpg = the filename of the GPG encrypted file
    # * targz = the filename of the unencrypted file
    # * passphrase = the string used to decrypt the file
    #
    # = Return value:
    # * The method will return true if the decryption is successful.
    # * The method will raise an exception if either the decryption command fails,
    # or a test for the existence of the decrypted file fails.
    # The exception's message will contain the explanation of the failure
    def FileUtilities.gpgdecrypt(workspace_dir, targzgpg, targz, passphrase)
      # LyberCore::Log.debug("decrypting #{targzgpg}")
      gpg_cmd = "/usr/bin/gpg --passphrase '#{passphrase}'  " +
          "--batch --no-mdc-warning --no-secmem-warning " +
          " --output " + File.join(workspace_dir, targz) +
          " --decrypt " + File.join(workspace_dir, targzgpg)
      self.execute(gpg_cmd)
      raise "#{targz} was not created in #{workspace_dir}" unless File.exists?(File.join(workspace_dir, targz))
      true
    end

    # Unpacks a TAR-ed, GZipped archive using a "tar -xzf" command
    #
    # = Inputs:
    # * original_dir = dirname containing the archive file
    # * targz = the filename of the archive file
    # * destination_dir = the target directory into which the contents are written
    #
    # = Return value:
    # * The method will return true if the unpacking is successful.
    # * The method will raise an exception if either the unpack command fails,
    # or a test for the existence of files in the target directory fails.
    # The exception's message will contain the explanation of the failure.
    def FileUtilities.unpack(original_dir, targz, destination_dir)
      # LyberCore::Log.debug("unpacking #{targz}")
      FileUtils.mkdir_p(destination_dir)
      dir_save = Dir.pwd
      Dir.chdir(destination_dir)
      unpack_cmd = "tar -xzf " + File.join(original_dir, targz)
      self.execute(unpack_cmd)
      raise "#{destination_dir} is empty" unless Dir.entries(destination_dir).length > 0
      true
    ensure
      Dir.chdir(dir_save)
    end

    # Tars a directory hierarchy
    #
    # = Inputs:
    # * source_path = the filesystem object to be tarred
    # * dest_path = name of the tar file to be written
    #     (if nil create sourcename.tar in the same dir as the source object)
    #
    # = Return value:
    # * The method will return true if the transfer is successful.
    # * The method will raise an exception if either the rsync command fails,
    # or a test for the existence of the transferred object fails.
    # The exception's message will contain the explanation of the failure
    #
    def FileUtilities.tar_object(source_path, dest_path=nil)
      dest_path = source_path + ".tar" if dest_path.nil?
      parent_path = File.dirname(source_path)
      object_name = File.basename(source_path)
      tar = "cd #{parent_path}; tar --force-local -chf "
      tar_cmd = "#{tar} '#{dest_path}' '#{object_name}'"
      self.execute(tar_cmd)
      raise "#{dest_path} was not created" unless File.exist?(dest_path)
      true
    end
  end
end
