export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[]

export interface Database {
    public: {
        Tables: {
            noticias: {
                Row: {
                    id: string
                    titulo: string
                    descripcion: string
                    image_url: string
                    url: string | null
                    user_id: string | null
                    created_at: string
                }
                Insert: {
                    id?: string
                    titulo: string
                    descripcion: string
                    image_url: string
                    url?: string | null
                    user_id?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    titulo?: string
                    descripcion?: string
                    image_url?: string
                    url?: string | null
                    user_id?: string | null
                    created_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "noticias_user_id_fkey"
                        columns: ["user_id"]
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    }
                ]
            }
            ofertas: {
                Row: {
                    id: string
                    comercio: string
                    titulo: string
                    descripcion: string
                    image_url: string
                    fecha_inicio: string
                    fecha_fin: string
                    nivel_requerido: string
                    user_id: string | null
                    created_at: string
                }
                Insert: {
                    id?: string
                    comercio: string
                    titulo: string
                    descripcion: string
                    image_url: string
                    fecha_inicio: string
                    fecha_fin: string
                    nivel_requerido: string
                    user_id?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    comercio?: string
                    titulo?: string
                    descripcion?: string
                    image_url?: string
                    fecha_inicio?: string
                    fecha_fin?: string
                    nivel_requerido?: string
                    user_id?: string | null
                    created_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "ofertas_user_id_fkey"
                        columns: ["user_id"]
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    }
                ]
            }
            cupones: {
                Row: {
                    id: string
                    nombre: string
                    imagen_url: string
                    descripcion: string
                    puntos_requeridos: number
                    store_id: string
                    fecha_fin: string | null
                    qr_code: string | null
                    nivel_requerido: string | null
                    estado: string | null
                    comercio: string
                    user_id: string | null
                    created_at: string
                }
                Insert: {
                    id?: string
                    nombre: string
                    imagen_url: string
                    descripcion: string
                    puntos_requeridos?: number
                    store_id: string
                    fecha_fin?: string | null
                    qr_code?: string | null
                    nivel_requerido?: string | null
                    estado?: string | null
                    comercio: string
                    user_id?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    nombre?: string
                    imagen_url?: string
                    descripcion?: string
                    puntos_requeridos?: number
                    store_id?: string
                    fecha_fin?: string | null
                    qr_code?: string | null
                    nivel_requerido?: string | null
                    estado?: string | null
                    comercio?: string
                    user_id?: string | null
                    created_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "cupones_user_id_fkey"
                        columns: ["user_id"]
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    }
                ]
            }
            usuarios: {
                Row: {
                    id: string
                    email: string
                    nombre: string | null
                    display_name: string | null
                    avatar_url: string | null
                    rol: string | null
                    token: string | null
                    comercios: Json | null
                    comercios_subs: Json | null
                    ultimo_acceso: string | null
                    created_at: string
                }
                Insert: {
                    id: string
                    email: string
                    nombre?: string | null
                    display_name?: string | null
                    avatar_url?: string | null
                    rol?: string | null
                    token?: string | null
                    comercios?: Json | null
                    comercios_subs?: Json | null
                    ultimo_acceso?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    email?: string
                    nombre?: string | null
                    display_name?: string | null
                    avatar_url?: string | null
                    rol?: string | null
                    token?: string | null
                    comercios?: Json | null
                    comercios_subs?: Json | null
                    ultimo_acceso?: string | null
                    created_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "usuarios_id_fkey"
                        columns: ["id"]
                        referencedRelation: "users"
                        referencedColumns: ["id"]
                    }
                ]
            }
            associations: {
                Row: {
                    id: string
                    nombre: string
                    descripcion: string | null
                    logo_url: string | null
                    admin_user_id: string
                    comercios_ids: string[]
                    activa: boolean
                    created_at: string
                    updated_at: string | null
                }
                Insert: {
                    id?: string
                    nombre: string
                    descripcion?: string | null
                    logo_url?: string | null
                    admin_user_id: string
                    comercios_ids?: string[]
                    activa?: boolean
                    created_at?: string
                    updated_at?: string | null
                }
                Update: {
                    id?: string
                    nombre?: string
                    descripcion?: string | null
                    logo_url?: string | null
                    admin_user_id?: string
                    comercios_ids?: string[]
                    activa?: boolean
                    created_at?: string
                    updated_at?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "associations_admin_user_id_fkey"
                        columns: ["admin_user_id"]
                        referencedRelation: "usuarios"
                        referencedColumns: ["id"]
                    }
                ]
            }
        }
        Views: {
            [_ in never]: never
        }
        Functions: {
            [_ in never]: never
        }
        Enums: {
            [_ in never]: never
        }
        CompositeTypes: {
            [_ in never]: never
        }
    }
}
