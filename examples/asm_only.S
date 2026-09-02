/* No instructions: portable across darwin/arm64 and linux/x86_64. This target
   exists to exercise the skip-recording path -- it contributes a library to
   the link but no bitcode, which is exactly what the manifest records. */
