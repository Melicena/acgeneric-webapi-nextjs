package com.virgisoft.acgeneric.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Modelo de datos para Asociaciones de Comercios
 * 
 * Una asociación permite a un usuario administrador gestionar
 * múltiples comercios bajo una misma entidad.
 */
@Serializable
data class AsociacionModel(
    val id: String,
    val nombre: String,
    val descripcion: String? = null,
    @SerialName("logo_url") val logoUrl: String? = null,
    @SerialName("admin_user_id") val adminUserId: String,
    @SerialName("comercios_ids") val comerciosIds: List<String> = emptyList(),
    val activa: Boolean = true,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null
) {
    /**
     * Verifica si la asociación está activa
     */
    fun isActive(): Boolean = activa
    
    /**
     * Obtiene el número de comercios en la asociación
     */
    fun getTotalComercios(): Int = comerciosIds.size
    
    /**
     * Verifica si un comercio pertenece a esta asociación
     */
    fun hasComercio(comercioId: String): Boolean {
        return comerciosIds.contains(comercioId)
    }
    
    /**
     * Verifica si el usuario dado es el administrador de esta asociación
     */
    fun isAdmin(userId: String): Boolean {
        return adminUserId == userId
    }
}

/**
 * Modelo de datos para Usuario (actualizado)
 * 
 * Incluye soporte para administración de asociaciones
 */
@Serializable
data class UsuarioModel(
    val id: String,
    val email: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val comercios: List<String>? = null,
    @SerialName("comercios_subs") val comerciosSubs: Map<String, Boolean>? = null,
    @SerialName("display_name") val displayName: String? = null,
    val rol: String,
    val token: String? = null,
    @SerialName("ultimo_acceso") val ultimoAcceso: String? = null,
    
    /**
     * Lista de asociaciones que administra este usuario
     * (Cargado mediante JOIN con associations donde admin_user_id = user.id)
     */
    @SerialName("managed_associations")
    val asociacionesAdministradas: List<AsociacionModel>? = null
) {
    companion object {
        // Roles de usuario
        const val ROL_USUARIO = "usuario"
        const val ROL_NEGOCIO = "negocio"
        const val ROL_ASOCIACION_ADMIN = "asociacion_admin"
    }
    
    /**
     * Verifica si el usuario es administrador de al menos una asociación
     */
    fun isAssociationAdmin(): Boolean {
        return !asociacionesAdministradas.isNullOrEmpty()
    }
    
    /**
     * Obtiene el total de asociaciones que administra
     */
    fun getTotalManagedAssociations(): Int {
        return asociacionesAdministradas?.size ?: 0
    }
    
    /**
     * Obtiene todos los comercios que puede administrar
     * (comercios directos + comercios de asociaciones)
     */
    fun getAllManagedComercios(): List<String> {
        val directComercios = comercios ?: emptyList()
        val associationComercios = asociacionesAdministradas
            ?.flatMap { it.comerciosIds }
            ?: emptyList()
        
        return (directComercios + associationComercios).distinct()
    }
    
    /**
     * Verifica si el usuario puede administrar un comercio específico
     * (ya sea directamente o a través de una asociación)
     */
    fun canManageComercio(comercioId: String): Boolean {
        // Verificar si está en comercios directos
        if (comercios?.contains(comercioId) == true) {
            return true
        }
        
        // Verificar si está en alguna asociación que administra
        return asociacionesAdministradas?.any { 
            it.hasComercio(comercioId) && it.isActive() 
        } ?: false
    }
    
    /**
     * Obtiene la asociación que contiene un comercio específico
     */
    fun getAssociationForComercio(comercioId: String): AsociacionModel? {
        return asociacionesAdministradas?.firstOrNull { 
            it.hasComercio(comercioId) && it.isActive() 
        }
    }
}

// ==========================================
// DTOs para Requests
// ==========================================

/**
 * DTO para crear una nueva asociación
 */
@Serializable
data class CreateAsociacionRequest(
    val nombre: String,
    val descripcion: String? = null,
    val logoUrl: String? = null,
    val comerciosIds: List<String> = emptyList()
)

/**
 * DTO para actualizar una asociación
 */
@Serializable
data class UpdateAsociacionRequest(
    val nombre: String? = null,
    val descripcion: String? = null,
    val logoUrl: String? = null,
    val comerciosIds: List<String>? = null,
    val activa: Boolean? = null
)

/**
 * DTO para agregar un comercio a una asociación
 */
@Serializable
data class AddComercioRequest(
    val comercioId: String
)

/**
 * DTO para remover un comercio de una asociación
 */
@Serializable
data class RemoveComercioRequest(
    val comercioId: String
)

// ==========================================
// Responses
// ==========================================

/**
 * Response genérica para operaciones con asociaciones
 */
@Serializable
data class AsociacionResponse(
    val success: Boolean,
    val data: AsociacionModel? = null,
    val message: String? = null,
    val error: String? = null
)

/**
 * Response para lista de asociaciones
 */
@Serializable
data class AsociacionesListResponse(
    val success: Boolean,
    val data: List<AsociacionModel> = emptyList(),
    val meta: Meta? = null
) {
    @Serializable
    data class Meta(
        val total: Int
    )
}

/**
 * Response para usuario con asociaciones
 */
@Serializable
data class UsuarioWithAssociationsResponse(
    val success: Boolean,
    val data: UsuarioModel? = null,
    val meta: UserMeta? = null
) {
    @Serializable
    data class UserMeta(
        val isAssociationAdmin: Boolean,
        val totalManagedAssociations: Int
    )
}
