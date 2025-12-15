import { Database } from './supabase/database.types'

// ==========================================
// Base Types (Helpers)
// ==========================================
export type Tables<T extends keyof Database['public']['Tables']> = Database['public']['Tables'][T]['Row']
export type Enums<T extends keyof Database['public']['Enums']> = Database['public']['Enums'][T]
export type InsertDto<T extends keyof Database['public']['Tables']> = Database['public']['Tables'][T]['Insert']
export type UpdateDto<T extends keyof Database['public']['Tables']> = Database['public']['Tables'][T]['Update']

// ==========================================
// Domain Models (Application Layer)
// Estas interfaces defines cómo usa tu aplicación los datos (CamelCase)
// ==========================================

export interface NoticiaModel {
    id: string
    titulo: string
    descripcion: string
    imageUrl: string
    url: string | null
    userId: string | null
    createdAt: string
}

// Roles de usuario
export const UserRoles = {
    USUARIO: 'usuario',
    NEGOCIO: 'negocio',
    ASOCIACION_ADMIN: 'asociacion_admin'
} as const

export type UserRole = typeof UserRoles[keyof typeof UserRoles]

export interface AsociacionModel {
    id: string
    nombre: string
    descripcion: string | null
    logoUrl: string | null
    adminUserId: string
    comerciosIds: string[]
    activa: boolean
    createdAt: string
    updatedAt: string | null
}

export interface UsuarioModel {
    id: string
    email: string
    displayName: string | null
    avatarUrl: string | null
    rol: UserRole
    comercios: string[] | null
    token: string | null
    ultimoAcceso: string | null
    createdAt: string
    /**
     * Lista de asociaciones que administra este usuario
     * (Cargado mediante JOIN con associations donde admin_user_id = user.id)
     */
    managedAssociations: AsociacionModel[] | null
}

export interface OfertaModel {
    id: string
    comercio: string
    comercioData?: {
        id: string
        nombre: string
        location?: any
        categoria?: string
        categorias?: any // Para soportar la columna plural de la DB
    }
    titulo: string
    descripcion: string
    imageUrl: string
    fechaInicio: string
    fechaFin: string
    nivelRequerido: string
    userId: string | null
    createdAt: string
    isFollowed?: boolean
}



// ==========================================
// Mappers (Data Transformation Layer)
// Funciones puras para transformar de DB (snake_case) a App (camelCase)
// ==========================================

export const NoticiaMapper = {
    toDomain: (row: Tables<'noticias'>): NoticiaModel => ({
        id: row.id,
        titulo: row.titulo,
        descripcion: row.descripcion,
        imageUrl: row.image_url,
        url: row.url,
        userId: row.user_id,
        createdAt: row.created_at
    }),

    toDbInsert: (model: Partial<NoticiaModel>): InsertDto<'noticias'> => ({
        // @ts-ignore
        titulo: model.titulo!,
        descripcion: model.descripcion!,
        image_url: model.imageUrl!,
        url: model.url,
        user_id: model.userId
    })
}

export const AsociacionMapper = {
    toDomain: (row: Tables<'associations'>): AsociacionModel => ({
        id: row.id,
        nombre: row.nombre,
        descripcion: row.descripcion,
        logoUrl: row.logo_url,
        adminUserId: row.admin_user_id,
        comerciosIds: Array.isArray(row.comercios_ids) ? row.comercios_ids as string[] : [],
        activa: row.activa ?? true,
        createdAt: row.created_at,
        updatedAt: row.updated_at
    }),

    toDbInsert: (model: Partial<AsociacionModel>): InsertDto<'associations'> => ({
        // @ts-ignore
        nombre: model.nombre!,
        descripcion: model.descripcion,
        logo_url: model.logoUrl,
        admin_user_id: model.adminUserId!,
        comercios_ids: model.comerciosIds || [],
        activa: model.activa ?? true
    })
}

export const UsuarioMapper = {
    toDomain: (row: Tables<'usuarios'>, managedAssociations?: AsociacionModel[]): UsuarioModel => ({
        id: row.id,
        email: row.email,
        displayName: row.display_name || row.nombre,
        avatarUrl: row.avatar_url,
        rol: (row.rol || UserRoles.USUARIO) as UserRole,
        comercios: Array.isArray(row.comercios) ? row.comercios as string[] : null,
        token: row.token,
        ultimoAcceso: row.ultimo_acceso,
        createdAt: row.created_at,
        managedAssociations: managedAssociations || null
    }),

    toDbInsert: (model: Partial<UsuarioModel>): InsertDto<'usuarios'> => ({
        // @ts-ignore
        id: model.id,
        email: model.email!,
        display_name: model.displayName,
        avatar_url: model.avatarUrl,
        rol: model.rol || UserRoles.USUARIO,
        comercios: model.comercios,
        token: model.token,
        ultimo_acceso: model.ultimoAcceso
    })
}

export const OfertaMapper = {
    toDomain: (row: Tables<'ofertas'> & { comercio?: any }): OfertaModel => ({
        id: row.id,
        comercio: row.comercio,
        comercioData: row.comercio ? {
            id: row.comercio.id,
            nombre: row.comercio.nombre,
            location: row.comercio.location,
            categoria: row.comercio.categorias, // Mapeamos categorias a categoria por compatibilidad
            categorias: row.comercio.categorias
        } : undefined,
        titulo: row.titulo,
        descripcion: row.descripcion,
        imageUrl: row.image_url,
        fechaInicio: row.fecha_inicio,
        fechaFin: row.fecha_fin,
        nivelRequerido: row.nivel_requerido,
        userId: row.user_id,
        createdAt: row.created_at
    }),

    toDbInsert: (model: Partial<OfertaModel>): InsertDto<'ofertas'> => ({
        // @ts-ignore
        comercio: model.comercio!,
        titulo: model.titulo!,
        descripcion: model.descripcion!,
        image_url: model.imageUrl!,
        fecha_inicio: model.fechaInicio!,
        fecha_fin: model.fechaFin!,
        nivel_requerido: model.nivelRequerido!,
        user_id: model.userId
    })
}


