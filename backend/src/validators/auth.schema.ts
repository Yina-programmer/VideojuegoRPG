import { z } from 'zod';

const username = z.string()
  .trim()
  .min(3, 'El nombre de usuario debe tener al menos 3 caracteres')
  .max(24, 'El nombre de usuario no puede superar 24 caracteres')
  .regex(/^[\p{L}\p{N}_.-]+$/u, 'Usa letras, numeros, punto, guion o guion bajo');

const password = z.string()
  .min(8, 'La contrasena debe tener al menos 8 caracteres')
  .max(256, 'La contrasena es demasiado larga');

export const registerSchema = z.object({
  username,
  email: z.string().trim().email('Correo electronico invalido').max(254),
  password,
  password_confirmation: z.string().max(256),
}).strict().superRefine((value, context) => {
  if (value.password !== value.password_confirmation) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['password_confirmation'],
      message: 'Las contrasenas no coinciden',
    });
  }
});

export const loginSchema = z.object({
  login: z.string().trim().min(1).max(254),
  password,
}).strict();

export function normalizeIdentity(value: string): string {
  return value.trim().normalize('NFKC').toLocaleLowerCase('es-CO');
}
