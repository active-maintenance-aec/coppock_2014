# coppock_2014/download_original.R
# Output: original/ (the 2014 deposit) and original_corrigendum/ (the 2016 corrigendum's
#   deposit); neither is redistributed in this repo
# Depends on: original_manifest.csv, original_corrigendum_manifest.csv
# Description: Fetch both deposited archives from Harvard Dataverse and verify every
#   file. Run this once before running anything in maintained/. Re-running is free:
#   files already present with the right checksum are not downloaded again.
#
#   The corrigendum's archive (doi:10.7910/DVN/H47CC6) is the working archive behind the
#   2016 corrigendum, deposited in 2026. Its ideal points are the ones the corrected
#   analysis uses; everything else in it matches the 2014 deposit column for column.
#
#   Each manifest carries two checksums per file. md5_served is the MD5 of the bytes
#   Dataverse returns for `?format=original`, which is what this code was written
#   against. md5_published is the checksum Dataverse displays. Here all fifty-two agree,
#   but they do not always: other deposits in this program carry published checksums
#   that verify neither the original nor the derived tabular file, so verification
#   runs against md5_served and any disagreement is reported.

library(tidyverse)
library(here)

here::i_am("download_original.R")

base_url <- "https://dataverse.harvard.edu/api/access/datafile"

fetch_archive <- function(manifest_file, folder, dataset_doi) {
  # Manifest ----
  manifest <- read_csv(here::here(manifest_file), show_col_types = FALSE)

  dir.create(here::here(folder), showWarnings = FALSE)

  # Download what is missing or wrong ----
  # format=original asks for the deposited bytes rather than the tabular
  # representation Dataverse derives for ingested files.
  planned <- manifest |>
    mutate(
      path = here::here(folder, file),
      url = str_glue("{base_url}/{dataverse_file_id}?format=original"),
      md5_local = unname(tools::md5sum(path)),
      needs_download = is.na(md5_local) | md5_local != md5_served
    )

  walk2(
    planned$url[planned$needs_download],
    planned$path[planned$needs_download],
    function(url, path) download.file(url, destfile = path, mode = "wb", quiet = TRUE)
  )

  print(str_glue("{folder}/: downloaded {sum(planned$needs_download)} of {nrow(planned)} ",
                 "files; {sum(!planned$needs_download)} already present and verified."))

  # Verify ----
  # md5_served is the MD5 of the bytes `?format=original` returns, and it is the gate.
  # md5_published is what Dataverse displays for those same bytes: where the two agree it
  # adds nothing a check could fail on, and where they disagree the archive's own metadata
  # is wrong and no local copy could satisfy both, so it is reported rather than enforced.
  verified <- planned |>
    mutate(
      md5_downloaded = unname(tools::md5sum(path)),
      bytes_on_disk = file.size(path),
      md5_ok = md5_downloaded == md5_served,
      bytes_ok = bytes_on_disk == bytes,
      published_agrees = md5_served == md5_published
    ) |>
    select(file, bytes, bytes_on_disk, bytes_ok, md5_served, md5_downloaded, md5_ok,
           published_agrees)

  print(verified |> select(file, bytes, bytes_ok, md5_ok, published_agrees), n = nrow(verified))

  if (!all(verified$md5_ok)) {
    stop("Checksum mismatch in ", folder, "/: ",
         paste(verified$file[!verified$md5_ok], collapse = ", "),
         ". Delete the offending files and re-run to refetch them from Dataverse.")
  }

  if (!all(verified$bytes_ok)) {
    stop("Byte size mismatch in ", folder, "/: ",
         paste(verified$file[!verified$bytes_ok], collapse = ", "), ".")
  }

  # The deposit and nothing else ----
  # Running the archive's own scripts inside the folder writes new files into it, which is
  # how a developer's copy comes to differ from a fresh clone. Anything extra stops the
  # run. all.files = TRUE is not optional: without it a stray dotfile passes unseen, and a
  # deposit can ship dotfiles of its own, which the manifest then has to list.
  extra <- setdiff(
    list.files(here::here(folder), recursive = TRUE, all.files = TRUE, no.. = TRUE),
    manifest$file
  )
  if (length(extra) > 0) {
    stop(folder, "/ holds files the manifest does not list: ",
         paste(extra, collapse = ", "),
         ". Move them elsewhere; ", folder, "/ is the deposit and only the deposit.")
  }

  print(str_glue("All {nrow(verified)} files in {folder}/ match on MD5 and byte size, and ",
                 "it holds nothing else. {sum(!verified$published_agrees)} carry a published ",
                 "checksum that disagrees with what Dataverse serves. Archive: {dataset_doi}"))
}

# The 2014 deposit ----
fetch_archive("original_manifest.csv", "original", "doi:10.7910/DVN/28664")

# The 2016 corrigendum's deposit ----
fetch_archive("original_corrigendum_manifest.csv", "original_corrigendum",
              "doi:10.7910/DVN/H47CC6")
