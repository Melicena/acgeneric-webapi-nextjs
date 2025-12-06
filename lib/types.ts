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

export interface UsuarioModel {
    id: string
    email: string
    displayName: string | null
    avatarUrl: string | null
    rol: string
    comercios: any
    comerciosSubs: any
    ultimoAcceso: string | null
    createdAt: string
}

export interface OfertaModel {
    id: string
    comercio: string
    titulo: string
    descripcion: string
    imageUrl: string
    fechaInicio: string
    fechaFin: string
    nivelRequerido: string
    userId: string | null
    createdAt: string
}

export interface CuponModel {
    id: string
    nombre: string
    imagenUrl: string
    descripcion: string
    puntosRequeridos: number
    storeId: string
    fechaFin: string | null
    qrCode: string | null
    nivelRequerido: string | null
    estado: string | null
    comercio: string
    userId: string | null
    createdAt: string
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

export const UsuarioMapper = {
    toDomain: (row: Tables<'usuarios'>): UsuarioModel => ({
        id: row.id,
        email: row.email,
        displayName: row.display_name || row.nombre,
        avatarUrl: row.avatar_url,
        rol: row.rol || 'CLIENTE',
        comercios: row.comercios,
        comerciosSubs: row.comercios_subs,
        ultimoAcceso: row.ultimo_acceso,
        createdAt: row.created_at
    })
}

export const OfertaMapper = {
    toDomain: (row: Tables<'ofertas'>): OfertaModel => ({
        id: row.id,
        comercio: row.comercio,
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

export const CuponMapper = {
    toDomain: (row: Tables<'cupones'>): CuponModel => ({
        id: row.id,
        nombre: row.nombre,
        imagenUrl: row.imagen_url,
        descripcion: row.descripcion,
        puntosRequeridos: row.puntos_requeridos,
        storeId: row.store_id,
        fechaFin: row.fecha_fin,
        qrCode: row.qr_code,
        nivelRequerido: row.nivel_requerido,
        estado: row.estado,
        comercio: row.comercio,
        userId: row.user_id,
        createdAt: row.created_at
    }),

    toDbInsert: (model: Partial<CuponModel>): InsertDto<'cupones'> => ({
        // @ts-ignore
        nombre: model.nombre!,
        imagen_url: model.imagenUrl!,
        descripcion: model.descripcion!,
        puntos_requeridos: model.puntosRequeridos,
        store_id: model.storeId!,
        fecha_fin: model.fechaFin,
        qr_code: model.qrCode,
        nivel_requerido: model.nivelRequerido,
        estado: model.estado,
        comercio: model.comercio!,
        user_id: model.userId
    })
}
