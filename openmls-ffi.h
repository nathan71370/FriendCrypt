//
//  FriendCrypt-Bridging-Header.h
//  FriendCrypt
//
//  Created by Nathan Mercier on 16/02/2025.
//

// include/openmls_ffi.h
#ifndef OPENMLS_FFI_H
#define OPENMLS_FFI_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Context structs to pass between languages
typedef struct GroupContext GroupContext;
typedef struct SignerContext SignerContext;
typedef struct CredentialContext CredentialContext;
typedef struct KeyPackageContext KeyPackageContext;
typedef struct WelcomeContext WelcomeContext;
typedef struct StagedWelcomeContext StagedWelcomeContext;

// Error handling
typedef struct {
    bool success;
    char* error_message;
} FfiResult;

// Free error message resources
void free_error_message(FfiResult result);

// Get default ciphersuite
uint32_t get_default_ciphersuite(void);

// Generate credential with key
FfiResult generate_credential(
    const char* identity,
    uint32_t ciphersuite_id,
    CredentialContext* out_credential,
    SignerContext* out_signer
);

// Free credential resources
void free_credential(CredentialContext context);

// Free signer resources
void free_signer(SignerContext context);

// Generate key package
FfiResult generate_key_package(
    uint32_t ciphersuite_id,
    const SignerContext* signer,
    const CredentialContext* credential,
    KeyPackageContext* out_key_package
);

// Free key package resources
void free_key_package(KeyPackageContext context);

// Create new MLS group
FfiResult create_mls_group(
    const SignerContext* signer,
    const CredentialContext* credential,
    GroupContext* out_group
);

// Free group resources
void free_group(GroupContext context);

// Add members to a group
FfiResult add_members(
    GroupContext* group,
    const SignerContext* signer,
    const KeyPackageContext* const* key_packages,
    size_t key_package_count,
    WelcomeContext* out_welcome
);

// Merge pending commit
FfiResult merge_pending_commit(
    GroupContext* group
);

// Export ratchet tree
FfiResult export_ratchet_tree(
    const GroupContext* group,
    uint8_t** out_data,
    size_t* out_len
);

// Serialize welcome message
FfiResult serialize_welcome(
    const WelcomeContext* welcome,
    uint8_t** out_data,
    size_t* out_len
);

// Free welcome resources
void free_welcome(WelcomeContext context);

// Free byte buffer
void free_buffer(uint8_t* buffer, size_t len);

// Deserialize welcome message
FfiResult deserialize_welcome(
    const uint8_t* data,
    size_t data_len,
    WelcomeContext* out_welcome
);

// Create staged join from welcome
FfiResult create_staged_welcome(
    const WelcomeContext* welcome,
    const uint8_t* ratchet_tree_data,
    size_t ratchet_tree_len,
    StagedWelcomeContext* out_staged_welcome
);

// Free staged welcome resources
void free_staged_welcome(StagedWelcomeContext context);

// Complete group join from staged welcome
FfiResult complete_group_join(
    StagedWelcomeContext* staged_welcome,
    GroupContext* out_group
);

#ifdef __cplusplus
}
#endif

#endif // OPENMLS_FFI_H
