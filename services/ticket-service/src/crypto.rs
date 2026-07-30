use ring::signature::Ed25519KeyPair;
use ring::rand::SystemRandom;
use sqlx::PgPool;

pub async fn load_or_create_signing_key(pool: &PgPool) -> Result<Ed25519KeyPair, Box<dyn std::error::Error>> {
    let row = sqlx::query_as::<_, (Vec<u8>,)>("SELECT private_key FROM signing_keys WHERE key_id = 'primary' ORDER BY created_at DESC LIMIT 1")
        .fetch_optional(pool)
        .await?;

    match row {
        Some((pkcs8_bytes,)) => {
            Ok(Ed25519KeyPair::from_pkcs8(&pkcs8_bytes)?)
        }
        None => {
            let rng = SystemRandom::new();
            let pkcs8_bytes = ring::signature::Ed25519KeyPair::generate_pkcs8(&rng)?;
            let key_pair = Ed25519KeyPair::from_pkcs8(pkcs8_bytes.as_ref())?;

            sqlx::query("INSERT INTO signing_keys (key_id, private_key, public_key, created_at) VALUES ('primary', $1, $2, NOW())")
                .bind(pkcs8_bytes.as_ref())
                .bind(key_pair.public_key().as_ref())
                .execute(pool)
                .await?;

            Ok(key_pair)
        }
    }
}

pub fn hash_passenger(name: &str, phone: &str) -> String {
    use ring::digest::{Context, SHA256};
    let mut context = Context::new(&SHA256);
    context.update(name.as_bytes());
    context.update(phone.as_bytes());
    base64::encode(context.finish().as_ref())
}
